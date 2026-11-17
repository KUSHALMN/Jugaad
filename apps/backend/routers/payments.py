from fastapi import APIRouter, Depends, HTTPException, Request
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared import redis_client
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


async def _reconcile_captured_payment(
    order_id: str,
    payment_id: str,
    amount_paise: int,
    notes: dict,
    event_id: str
) -> dict:
    """
    Reconciles captured payment or paid order against the jobs database idempotently.
    Updates escrow and releases payout if job criteria are satisfied.
    """
    # 1. Look up job by razorpay_order_id or notes.job_id
    job = None
    if order_id:
        job_result = supabase.table("jobs").select("id, employer_id, worker_id, status, payment_status").eq("razorpay_order_id", order_id).maybe_single().execute()
        if job_result and job_result.data:
            job = job_result.data

    if not job and notes and notes.get("job_id"):
        job_result = supabase.table("jobs").select("id, employer_id, worker_id, status, payment_status").eq("id", notes["job_id"]).maybe_single().execute()
        if job_result and job_result.data:
            job = job_result.data

    if not job:
        logger.warning(f"Reconciliation target not found for order={order_id}, notes={notes}")
        return {"status": "job_not_found", "order_id": order_id}

    job_id = job.get("id")

    # 2. Check if payment was already recorded in payments table
    if payment_id:
        existing_pmt = supabase.table("payments").select("id, status").eq("razorpay_payment_id", payment_id).execute()
        if existing_pmt and existing_pmt.data:
            logger.info(f"Payment {payment_id} already recorded in DB")
            return {"status": "already_recorded", "job_id": job_id, "payment_id": payment_id}

    # 3. Escrow rule evaluation:
    # Release payout if and only if job is completed AND there are no unresolved price change requests
    is_completed = job.get("status") == "completed"
    has_pending_requests = False
    if job_id:
        pending_res = supabase.table("price_change_requests").select("id").eq("job_id", job_id).eq("status", "pending").execute()
        has_pending_requests = bool(pending_res.data)

    payment_release_status = "released" if (is_completed and not has_pending_requests) else "escrowed"

    # 4. Insert payment record into payments ledger
    try:
        supabase.table("payments").insert({
            "job_id": job_id,
            "employer_id": job.get("employer_id"),
            "worker_id": job.get("worker_id"),
            "amount": float(amount_paise) / 100.0,
            "razorpay_order_id": order_id or "",
            "razorpay_payment_id": payment_id or "",
            "status": payment_release_status,
        }).execute()
    except Exception as ins_err:
        logger.warning(f"Payment ledger insert note: {ins_err}")

    # 5. Atomically transition job payment status
    if job_id:
        update_data = {
            "payment_status": payment_release_status,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        if payment_id:
            update_data["razorpay_payment_id"] = payment_id

        supabase.table("jobs").update(update_data).eq("id", job_id).execute()
        logger.info(f"✅ Job {job_id} payment auto-reconciled to '{payment_release_status}' via webhook")

    # 6. Try to send FCM push notification to participants
    try:
        from services.fcm_service import fcm_service
        employer_id = job.get("employer_id")
        worker_id = job.get("worker_id")
        amount_inr = float(amount_paise) / 100.0

        if employer_id:
            emp_res = supabase.table("users").select("fcm_token").eq("id", employer_id).execute()
            if emp_res.data and emp_res.data[0].get("fcm_token"):
                await fcm_service.send_silent_fcm(emp_res.data[0]["fcm_token"], {
                    "type": "PAYMENT_CONFIRMED",
                    "job_id": job_id,
                    "payment_status": payment_release_status,
                    "amount": str(amount_inr)
                })

        if worker_id and payment_release_status == "released":
            w_res = supabase.table("users").select("fcm_token").eq("id", worker_id).execute()
            if w_res.data and w_res.data[0].get("fcm_token"):
                await fcm_service.send_silent_fcm(w_res.data[0]["fcm_token"], {
                    "type": "PAYMENT_RELEASED",
                    "job_id": job_id,
                    "amount": str(amount_inr)
                })
    except Exception as fcm_err:
        logger.warning(f"Optional FCM alert error on webhook reconciliation: {fcm_err}")

    return {
        "status": "reconciled",
        "job_id": job_id,
        "payment_status": payment_release_status,
        "order_id": order_id,
        "payment_id": payment_id
    }


async def _handle_payment_failed(
    order_id: str,
    payment_id: str,
    error_desc: str,
    notes: dict,
    event_id: str
) -> dict:
    """Reconciles payment failure against jobs and alerts employer to retry."""
    job = None
    if order_id:
        job_result = supabase.table("jobs").select("id, employer_id, status, payment_status").eq("razorpay_order_id", order_id).maybe_single().execute()
        if job_result and job_result.data:
            job = job_result.data

    if not job and notes and notes.get("job_id"):
        job_result = supabase.table("jobs").select("id, employer_id, status, payment_status").eq("id", notes["job_id"]).maybe_single().execute()
        if job_result and job_result.data:
            job = job_result.data

    if not job:
        logger.warning(f"Payment failed webhook for untracked order={order_id}")
        return {"status": "job_not_found", "order_id": order_id}

    job_id = job.get("id")
    # Only mark failed if payment has not already been settled or released
    if job.get("payment_status") not in ("released", "settled"):
        supabase.table("jobs").update({
            "payment_status": "failed",
            "updated_at": datetime.now(timezone.utc).isoformat()
        }).eq("id", job_id).execute()

    # Alert employer via push notification to retry payment
    try:
        from services.fcm_service import fcm_service
        employer_id = job.get("employer_id")
        if employer_id:
            emp_res = supabase.table("users").select("fcm_token").eq("id", employer_id).execute()
            if emp_res.data and emp_res.data[0].get("fcm_token"):
                await fcm_service.send_silent_fcm(emp_res.data[0]["fcm_token"], {
                    "type": "PAYMENT_FAILED",
                    "job_id": job_id,
                    "error_description": error_desc or "Payment could not be completed"
                })
    except Exception as fcm_err:
        logger.warning(f"Could not dispatch payment failed push notification: {fcm_err}")

    logger.warning(f"⚠️ Payment failed for job {job_id} (order={order_id}): {error_desc}")
    return {"status": "failed_reconciled", "job_id": job_id, "error": error_desc}


async def _handle_refund_processed(
    refund_id: str,
    payment_id: str,
    amount_paise: int,
    notes: dict,
    event_id: str
) -> dict:
    """Reconciles refund status on payments and jobs tables."""
    # 1. Update payments table
    updated_pmt = None
    if payment_id:
        res = supabase.table("payments").update({
            "status": "refunded",
            "updated_at": datetime.now(timezone.utc).isoformat()
        }).eq("razorpay_payment_id", payment_id).execute()
        if res and res.data:
            updated_pmt = res.data[0]

    # 2. Update jobs table
    job_id = notes.get("job_id") if notes else None
    if not job_id and updated_pmt:
        job_id = updated_pmt.get("job_id")

    if not job_id and payment_id:
        job_res = supabase.table("jobs").select("id, employer_id").eq("razorpay_payment_id", payment_id).maybe_single().execute()
        if job_res and job_res.data:
            job_id = job_res.data["id"]

    if job_id:
        supabase.table("jobs").update({
            "payment_status": "refunded",
            "updated_at": datetime.now(timezone.utc).isoformat()
        }).eq("id", job_id).execute()

        # Send push notification to employer confirming refund
        try:
            from services.fcm_service import fcm_service
            job_res = supabase.table("jobs").select("employer_id").eq("id", job_id).maybe_single().execute()
            if job_res and job_res.data and job_res.data.get("employer_id"):
                emp_res = supabase.table("users").select("fcm_token").eq("id", job_res.data["employer_id"]).execute()
                if emp_res.data and emp_res.data[0].get("fcm_token"):
                    await fcm_service.send_silent_fcm(emp_res.data[0]["fcm_token"], {
                        "type": "REFUND_PROCESSED",
                        "job_id": job_id,
                        "refund_id": refund_id,
                        "amount": str(float(amount_paise) / 100.0)
                    })
        except Exception as fcm_err:
            logger.warning(f"Could not dispatch refund push notification: {fcm_err}")

    logger.info(f"↩️ Refund {refund_id} reconciled for payment {payment_id}, job {job_id}")
    return {"status": "refund_reconciled", "job_id": job_id, "refund_id": refund_id}


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

    # 1. Distributed idempotency check via Redis
    idempotency_key = f"webhook:processed:{event_id}"
    if redis_client.get_state(idempotency_key):
        logger.info(f"Webhook event {event_id} already processed, skipping duplicate delivery")
        return {"status": "already_processed", "event_id": event_id}

    lock_key = f"webhook:lock:{event_id}"
    acquired = redis_client.acquire_lock(lock_key, "processing", ex=30)

    try:
        payload_data = event.get("payload", {})
        result = {"status": "ignored", "event": event_type}

        if event_type in ("payment.captured", "order.paid"):
            payment_entity = payload_data.get("payment", {}).get("entity", {})
            order_entity = payload_data.get("order", {}).get("entity", {})
            
            order_id = payment_entity.get("order_id") or order_entity.get("id", "")
            payment_id = payment_entity.get("id", "")
            amount = payment_entity.get("amount") or order_entity.get("amount_paid", 0)
            notes = payment_entity.get("notes") or order_entity.get("notes") or {}

            result = await _reconcile_captured_payment(
                order_id=order_id,
                payment_id=payment_id,
                amount_paise=amount,
                notes=notes,
                event_id=event_id
            )
        elif event_type == "payment.failed":
            payment_entity = payload_data.get("payment", {}).get("entity", {})
            order_id = payment_entity.get("order_id", "")
            payment_id = payment_entity.get("id", "")
            error_desc = payment_entity.get("error_description", "")
            notes = payment_entity.get("notes") or {}

            result = await _handle_payment_failed(
                order_id=order_id,
                payment_id=payment_id,
                error_desc=error_desc,
                notes=notes,
                event_id=event_id
            )
        elif event_type in ("refund.processed", "refund.created"):
            refund_entity = payload_data.get("refund", {}).get("entity", {})
            refund_id = refund_entity.get("id", "")
            payment_id = refund_entity.get("payment_id", "")
            amount = refund_entity.get("amount", 0)
            notes = refund_entity.get("notes") or {}

            result = await _handle_refund_processed(
                refund_id=refund_id,
                payment_id=payment_id,
                amount_paise=amount,
                notes=notes,
                event_id=event_id
            )

        # Mark event as idempotently processed in Redis (7 days TTL)
        redis_client.set_state(idempotency_key, "processed", ex=604800)
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Webhook processing error for {event_id}: {e}")
        raise HTTPException(500, "Internal webhook processing error")
    finally:
        redis_client.release_lock(lock_key)

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

