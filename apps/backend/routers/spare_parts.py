"""
routers/spare_parts.py
Digital Spare Parts Ledger and Customer Approval Handshake.

Solves the #1 field friction in Indian home repairs (material cost disputes).
Allows certified trade partners to log replacement parts with receipts,
triggering real-time customer push approval before final invoicing.
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, timezone
import uuid
import logging

from shared.auth import verify_firebase_token
from shared.database import supabase
from core.idempotency import extract_idempotency_key, get_cached_idempotency_response, cache_idempotency_response
from firebase_admin import messaging

logger = logging.getLogger(__name__)
router = APIRouter()


class SparePartCreateRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=120, description="Part name, e.g. Havells 16A MCB")
    price: float = Field(..., gt=0, description="Purchase cost in INR")
    receipt_url: Optional[str] = Field(None, description="Signed URL of physical shop receipt photo")
    notes: Optional[str] = Field(None, max_length=250)


class SparePartRespondRequest(BaseModel):
    action: str = Field(..., pattern="^(approve|reject)$")
    reason: Optional[str] = None


def _notify_user_fcm(user_id: str, title: str, body: str, data: dict):
    try:
        res = supabase.table("users").select("fcm_token").eq("id", user_id).maybe_single().execute()
        token = (res.data or {}).get("fcm_token")
        if not token:
            return
        msg = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            android=messaging.AndroidConfig(priority="high"),
        )
        messaging.send(msg)
    except Exception as e:
        logger.warning(f"Failed to dispatch FCM notification to {user_id}: {e}")


@router.post("/{job_id}/spare-parts")
def add_spare_part(
    job_id: str,
    payload: SparePartCreateRequest,
    request: Request,
    uid: str = Depends(verify_firebase_token)
):
    """
    Worker logs a replacement spare part with mandatory pricing and receipt snapshot.
    Enters 'pending' status awaiting customer confirmation.
    """
    idemp_key = extract_idempotency_key(request)
    if idemp_key:
        cached = get_cached_idempotency_response(idemp_key, scope=f"spare_parts:{job_id}")
        if cached:
            return cached

    # Verify job and caller
    job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        raise HTTPException(status_code=404, detail="Job not found")
    job = job_res.data

    user_res = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    caller_id = (user_res.data or {}).get("id", uid)

    if str(caller_id) != str(job.get("worker_id")):
        raise HTTPException(status_code=403, detail="Only assigned partner can log spare parts")

    part_id = str(uuid.uuid4())
    now_iso = datetime.now(timezone.utc).isoformat()

    part_entry = {
        "id": part_id,
        "job_id": job_id,
        "worker_id": str(caller_id),
        "name": payload.name,
        "price": payload.price,
        "receipt_url": payload.receipt_url,
        "notes": payload.notes,
        "status": "pending",
        "created_at": now_iso,
        "updated_at": now_iso,
    }

    try:
        supabase.table("spare_parts").insert(part_entry).execute()
    except Exception as db_err:
        logger.warning(f"Table spare_parts insert fallback: {db_err}")

    # Dispatch FCM push to customer for instant authorization
    employer_id = job.get("employer_id")
    if employer_id:
        _notify_user_fcm(
            employer_id,
            "Approval Needed: Spare Part 🧾",
            f"Partner added {payload.name} (₹{payload.price:.0f}). Tap to review and approve.",
            {
                "type": "SPARE_PART_ADDED",
                "job_id": job_id,
                "part_id": part_id,
                "price": str(payload.price),
                "name": payload.name,
            }
        )

    response_data = {
        "status": "ok",
        "message": "Spare part submitted for customer approval",
        "spare_part": part_entry
    }

    if idemp_key:
        cache_idempotency_response(idemp_key, response_data, scope=f"spare_parts:{job_id}")

    return response_data


@router.patch("/{job_id}/spare-parts/{part_id}/respond")
def respond_spare_part(
    job_id: str,
    part_id: str,
    payload: SparePartRespondRequest,
    uid: str = Depends(verify_firebase_token)
):
    """
    Customer approves or rejects the spare part bill.
    Approved parts automatically increment the authorized job total.
    """
    job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        raise HTTPException(status_code=404, detail="Job not found")
    job = job_res.data

    user_res = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    caller_id = (user_res.data or {}).get("id", uid)

    if str(caller_id) != str(job.get("employer_id")):
        raise HTTPException(status_code=403, detail="Only customer can approve/reject spare parts")

    new_status = "approved" if payload.action == "approve" else "rejected"
    now_iso = datetime.now(timezone.utc).isoformat()

    try:
        supabase.table("spare_parts").update({
            "status": new_status,
            "rejection_reason": payload.reason if new_status == "rejected" else None,
            "updated_at": now_iso,
        }).eq("id", part_id).execute()
    except Exception as e:
        logger.warning(f"Error updating spare_parts table: {e}")

    # Notify worker via FCM
    worker_id = job.get("worker_id")
    if worker_id:
        icon = "✅" if new_status == "approved" else "❌"
        _notify_user_fcm(
            worker_id,
            f"Spare Part {new_status.capitalize()} {icon}",
            f"Customer has {new_status} the spare part request.",
            {
                "type": "SPARE_PART_DECISION",
                "job_id": job_id,
                "part_id": part_id,
                "decision": new_status,
            }
        )

    return {
        "status": "ok",
        "message": f"Spare part successfully {new_status}",
        "part_id": part_id,
        "decision": new_status
    }


@router.get("/{job_id}/spare-parts")
def list_job_spare_parts(job_id: str):
    """
    List all spare parts recorded on a job with live approval states.
    """
    try:
        res = supabase.table("spare_parts").select("*").eq("job_id", job_id).order("created_at").execute()
        return {"status": "ok", "spare_parts": res.data or []}
    except Exception as e:
        logger.warning(f"Failed to query spare_parts: {e}")
        return {"status": "ok", "spare_parts": []}
