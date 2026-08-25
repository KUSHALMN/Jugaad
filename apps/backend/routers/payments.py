from fastapi import APIRouter, Depends, HTTPException, Request
from shared.auth import verify_firebase_token
from shared.database import supabase
from datetime import datetime, timezone
import logging
import hmac
import hashlib
import os
import json

logger = logging.getLogger(__name__)
router = APIRouter()

WHOOK = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")

@router.post("/webhooks/razorpay")
async def razorpay_webhook(request: Request):
    body_bytes = await request.body()
    sig = request.headers.get("X-Razorpay-Signature", "")

    if WHOOK:
        expected = hmac.new(WHOOK.encode(), body_bytes, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, sig):
            raise HTTPException(400, "Invalid signature")

    try:
        event = json.loads(body_bytes)
        event_type = event.get("event", "")
        payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id", "")
        payment_id = payment_entity.get("id", "")
        amount = payment_entity.get("amount", 0)

        if event_type == "payment.captured":
            existing = supabase.table("payments").select("id").eq("razorpay_payment_id", payment_id).execute()
            if existing.data:
                return {"status": "already_processed"}

            job_result = supabase.table("jobs").select("id, employer_id, worker_id, status").eq("razorpay_order_id", order_id).single().execute()
            job = job_result.data or {}
            job_id = job.get("id")

            # Check escrow release constraints
            is_completed = job.get("status") == "completed"
            has_pending = False
            if job_id:
                pending_requests = supabase.table("price_change_requests").select("id").eq("job_id", job_id).eq("status", "pending").execute()
                has_pending = bool(pending_requests.data)

            # Release payout only if job is marked complete and there are no pending price requests
            payment_release_status = "released" if (is_completed and not has_pending) else "escrowed"

            supabase.table("payments").insert({
                "job_id": job_id,
                "employer_id": job.get("employer_id"),
                "worker_id": job.get("worker_id"),
                "amount": amount / 100,
                "razorpay_order_id": order_id,
                "razorpay_payment_id": payment_id,
                "status": payment_release_status,
            }).execute()

            if job_id:
                supabase.table("jobs").update({
                    "payment_status": payment_release_status,
                    "razorpay_payment_id": payment_id,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", job_id).execute()

        return {"status": "processed"}
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        raise HTTPException(500, "Internal error")

@router.post("/verify")
def verify_payment(body: dict, uid: str = Depends(verify_firebase_token)):
    order_id = body.get("razorpay_order_id", "")
    payment_id = body.get("razorpay_payment_id", "")
    signature = body.get("razorpay_signature", "")

    key_secret = os.getenv("RAZORPAY_KEY_SECRET", "")
    
    # 1. Fetch job details associated with order
    job_result = supabase.table("jobs").select("id, status").eq("razorpay_order_id", order_id).maybe_single().execute()
    if not job_result or not job_result.data:
        raise HTTPException(404, "Job not found for this order")
    job = job_result.data
    job_id = job["id"]

    # 2. Assert constraints for releasing payment
    if job.get("status") != "completed":
        raise HTTPException(400, "Cannot release payment: job must be completed first")

    pending_requests = supabase.table("price_change_requests").select("id").eq("job_id", job_id).eq("status", "pending").execute()
    if pending_requests.data:
        raise HTTPException(400, "Cannot release payment: a price change request is pending approval")

    # Local simulation bypass
    if not key_secret or key_secret == "rzp_test_placeholder_key_secret" or signature == "mock_signature":
        logger.info("Local mode / Mock payment verification bypass activated.")
        supabase.table("jobs").update({
            "payment_status": "released",
            "razorpay_payment_id": payment_id,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", job_id).execute()
        return {"status": "verified", "payment_id": payment_id}

    message = f"{order_id}|{payment_id}"
    expected = hmac.new(key_secret.encode(), message.encode(), hashlib.sha256).hexdigest()

    if not hmac.compare_digest(expected, signature):
        raise HTTPException(400, "Invalid payment signature")

    supabase.table("jobs").update({
        "payment_status": "released",
        "razorpay_payment_id": payment_id,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    return {"status": "verified", "payment_id": payment_id}

