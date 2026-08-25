import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared.logging import log
from datetime import datetime, timezone
import hmac
import hashlib
import os
import json
import traceback
import uuid

app = FastAPI(title="Payment Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
WHOOK = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


@app.get("/health")
def health():
    return {"status": "ok", "service": "payment_service"}


@app.post("/v1/webhooks/razorpay")
def razorpay_webhook(request: Request):
    """Razorpay webhook — verifies signature and records payment in Supabase."""
    body_bytes = request.state.raw_body
    sig = request.headers.get("X-Razorpay-Signature", "")

    if not WHOOK:
        log("payment_service", "webhook", "no_secret_configured", severity="ERROR")
        raise HTTPException(500, "Webhook secret not configured")

    expected = hmac.new(WHOOK.encode(), body_bytes, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, sig):
        log("payment_service", "webhook", "invalid_signature", severity="WARNING")
        raise HTTPException(400, "Invalid signature")

    try:
        event = json.loads(body_bytes)
        event_type = event.get("event", "")
        payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id", "")
        payment_id = payment_entity.get("id", "")
        amount = payment_entity.get("amount", 0)

        if event_type == "payment.captured":
            # Idempotency: skip if this payment was already recorded
            existing = supabase.table("payments").select("id").eq("razorpay_payment_id", payment_id).execute()
            if existing.data:
                log("payment_service", "webhook", "duplicate_skipped",
                    payment_id=payment_id, order_id=order_id)
                return {"status": "already_processed"}

            # Find job by razorpay_order_id
            job_result = supabase.table("jobs").select("id, employer_id, worker_id").eq("razorpay_order_id", order_id).single().execute()
            job = job_result.data or {}

            supabase.table("payments").insert({
                "job_id": job.get("id"),
                "employer_id": job.get("employer_id"),
                "worker_id": job.get("worker_id"),
                "amount": amount / 100,
                "razorpay_order_id": order_id,
                "razorpay_payment_id": payment_id,
                "status": "released",
            }).execute()

            # Update job payment status
            if job.get("id"):
                supabase.table("jobs").update({
                    "payment_status": "released",
                    "razorpay_payment_id": payment_id,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", job["id"]).execute()

            log("payment_service", "webhook", "payment_captured",
                payment_id=payment_id, order_id=order_id, amount=amount)

        elif event_type == "payment.failed":
            # Look up job from order_id (may not exist for truly orphaned payments)
            failed_job = {}
            if order_id:
                failed_result = supabase.table("jobs").select("id, employer_id").eq("razorpay_order_id", order_id).execute()
                failed_job = failed_result.data[0] if failed_result.data else {}
            supabase.table("payments").insert({
                "job_id": failed_job.get("id"),
                "employer_id": failed_job.get("employer_id"),
                "amount": amount / 100,
                "razorpay_order_id": order_id,
                "razorpay_payment_id": payment_id,
                "status": "failed",
            }).execute()
            log("payment_service", "webhook", "payment_failed",
                payment_id=payment_id, severity="WARNING")

        return {"status": "processed"}

    except json.JSONDecodeError:
        raise HTTPException(400, "Invalid JSON body")
    except Exception as e:
        log("payment_service", "webhook", "processing_error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal error")


@app.post("/v1/jobs/{job_id}/create-order")
def create_order(job_id: str, uid: str = Depends(verify_firebase_token)):
    """Creates a Razorpay payment order for a completed job. Razorpay logic UNCHANGED."""
    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    # Verify the authenticated user owns this job
    if job.get("employer_id") != uid:
        raise HTTPException(403, "Not authorized to pay for this job")

    amount_rupees = job.get("amount", 0) or 500.0
    amount_paise = int(amount_rupees * 100)

    key_id = os.getenv("RAZORPAY_KEY_ID", "")
    key_secret = os.getenv("RAZORPAY_KEY_SECRET", "")

    simulated_order_id = f"order_{uuid.uuid4().hex[:12]}"

    if not key_id or not key_secret or key_id == "placeholder":
        order_data = {
            "id": simulated_order_id,
            "entity": "order",
            "amount": amount_paise,
            "amount_paid": 0,
            "amount_due": amount_paise,
            "currency": "INR",
            "receipt": job_id,
            "status": "created",
            "simulated": True,
        }
    else:
        try:
            import razorpay
            client = razorpay.Client(auth=(key_id, key_secret))
            order_data = client.order.create(data={
                "amount": amount_paise,
                "currency": "INR",
                "receipt": job_id[:40],
                "payment_capture": 1,
            })
        except Exception as e:
            log("payment_service", "create_order", "razorpay_error",
                severity="WARNING", error=str(e))
            order_data = {
                "id": simulated_order_id, "amount": amount_paise,
                "currency": "INR", "status": "created", "simulated": True,
            }

    # Store order reference
    supabase.table("jobs").update({
        "razorpay_order_id": order_data["id"],
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    log("payment_service", "create_order", "created",
        job_id=job_id, order_id=order_data["id"], amount=amount_paise)

    return order_data


@app.post("/v1/payments/verify")
def verify_payment(body: dict, uid: str = Depends(verify_firebase_token)):
    """Verify Razorpay payment signature after Flutter checkout.

    The Razorpay SDK returns (order_id, payment_id, signature) to the client.
    We verify: HMAC_SHA256(order_id|payment_id, KEY_SECRET) == signature.
    This ensures the payment was genuinely processed by Razorpay.
    """
    order_id = body.get("razorpay_order_id", "")
    payment_id = body.get("razorpay_payment_id", "")
    signature = body.get("razorpay_signature", "")

    key_secret = os.getenv("RAZORPAY_KEY_SECRET", "")
    if not key_secret:
        log("payment_service", "verify", "no_key_secret", severity="ERROR")
        raise HTTPException(500, "Payment verification not configured")

    # HMAC SHA256: order_id|payment_id signed with key_secret
    message = f"{order_id}|{payment_id}"
    expected = hmac.new(key_secret.encode(), message.encode(), hashlib.sha256).hexdigest()

    if not hmac.compare_digest(expected, signature):
        log("payment_service", "verify", "invalid_signature", severity="WARNING",
            order_id=order_id, payment_id=payment_id)
        raise HTTPException(400, "Invalid payment signature")

    # Update job payment status (idempotent — safe if webhook already fired)
    job_result = supabase.table("jobs").select("id").eq("razorpay_order_id", order_id).execute()
    if job_result.data:
        job_id = job_result.data[0]["id"]
        supabase.table("jobs").update({
            "payment_status": "released",
            "razorpay_payment_id": payment_id,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", job_id).execute()

    log("payment_service", "verify", "success", order_id=order_id, payment_id=payment_id)
    return {"status": "verified", "payment_id": payment_id}
