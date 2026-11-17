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


def verify_razorpay_webhook_signature(body_bytes: bytes, signature: str, secret: str) -> bool:
    """
    Cryptographically verify incoming Razorpay webhook signature using HMAC SHA-256.
    Uses timing-safe comparison to prevent side-channel timing attacks.
    """
    if not secret or not signature or not body_bytes:
        return False
    try:
        expected = hmac.new(secret.encode("utf-8"), body_bytes, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)
    except Exception as e:
        logger.error(f"Error computing webhook HMAC signature: {e}")
        return False


def parse_razorpay_webhook_payload(body_bytes: bytes) -> dict:
    """
    Safely deserialize and validate Razorpay webhook payload structure.
    """
    try:
        event = json.loads(body_bytes.decode("utf-8") if isinstance(body_bytes, bytes) else body_bytes)
        if not isinstance(event, dict) or "event" not in event:
            raise ValueError("Malformed Razorpay webhook structure: missing 'event' field")
        return event
    except Exception as e:
        logger.error(f"Failed to parse Razorpay webhook payload: {e}")
        raise HTTPException(400, f"Malformed webhook JSON: {str(e)}")


@router.post("/webhooks/razorpay")
async def razorpay_webhook(request: Request):
    body_bytes = await request.body()
    sig = request.headers.get("X-Razorpay-Signature", "")

    whook_secret = os.getenv("RAZORPAY_WEBHOOK_SECRET") or WHOOK
    if not whook_secret:
        logger.error("RAZORPAY_WEBHOOK_SECRET is not configured on the server")
        raise HTTPException(500, "Webhook secret not configured")

    if not sig:
        logger.warning("Received Razorpay webhook missing X-Razorpay-Signature header")
        raise HTTPException(400, "Missing webhook signature")

    if not verify_razorpay_webhook_signature(body_bytes, sig, whook_secret):
        logger.warning("Invalid Razorpay webhook signature attempt")
        raise HTTPException(400, "Invalid signature")

    event = parse_razorpay_webhook_payload(body_bytes)
    event_type = event.get("event", "")
    event_id = event.get("id") or f"evt_{hashlib.md5(body_bytes).hexdigest()}"
    logger.info(f"Verified Razorpay webhook received: type={event_type}, id={event_id}")

    try:
        payment_entity = event.get("payload", {}).get("payment", {}).get("entity", {})
        order_id = payment_entity.get("order_id", "")
        payment_id = payment_entity.get("id", "")
        amount = payment_entity.get("amount", 0)

        if event_type == "payment.captured":
            existing = supabase.table("payments").select("id").eq("razorpay_payment_id", payment_id).execute()
            if existing.data:
                return {"status": "already_processed"}

            job_result = supabase.table("jobs").select("id, employer_id, worker_id, status").eq("razorpay_order_id", order_id).maybe_single().execute()
            if not job_result or not job_result.data:
                logger.warning(f"Payment captured for unknown order: {order_id}")
                return {"status": "order_not_found"}

            job = job_result.data
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

    if not order_id or not payment_id or not signature:
        raise HTTPException(400, "Valid razorpay_order_id, razorpay_payment_id, and razorpay_signature are required")

    key_secret = os.getenv("RAZORPAY_KEY_SECRET", "")

    # 1. Fetch job details associated with order
    job_result = supabase.table("jobs").select("id, status, employer_id").eq("razorpay_order_id", order_id).maybe_single().execute()
    if not job_result or not job_result.data:
        raise HTTPException(404, "Job not found for this order")
    job = job_result.data
    job_id = job["id"]

    # Verify caller is the employer of the job
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    caller_id = (user_result.data or {}).get("id", uid)
    if job.get("employer_id") != caller_id and job.get("employer_id") != uid:
        raise HTTPException(403, "Not authorized to verify payment for this job")

    # 2. Check for sandbox / test simulation checkout
    is_simulated = (
        signature == "sig_simulated_success"
        or payment_id.startswith("pay_sim_")
        or not key_secret
        or key_secret == "placeholder"
        or key_secret == "rzp_test_placeholder_key_secret"
    )

    if not is_simulated:
        # Verify Razorpay cryptographic signature
        message = f"{order_id}|{payment_id}"
        expected = hmac.new(key_secret.encode(), message.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, signature):
            raise HTTPException(400, "Invalid payment signature")

    # 3. Determine status: 'released' if job is finished with no pending price changes, else 'escrowed'
    is_completed = job.get("status") == "completed"
    pending_requests = supabase.table("price_change_requests").select("id").eq("job_id", job_id).eq("status", "pending").execute()
    has_pending = bool(pending_requests.data)

    if is_completed and not has_pending:
        new_payment_status = "released"
    else:
        new_payment_status = "escrowed"

    supabase.table("jobs").update({
        "payment_status": new_payment_status,
        "razorpay_payment_id": payment_id,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    return {
        "status": "verified",
        "payment_status": new_payment_status,
        "payment_id": payment_id
    }

