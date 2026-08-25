import json
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Request
from pydantic import BaseModel, Field, field_validator
from typing import Optional, Literal
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared.models import CreateJobRequest, AcceptJobRequest, CompleteJobRequest, RejectJobRequest, VALID_SKILLS, JobRequestCreate, JobRequestResponse, JobRespondRequest, JobCancelRequest
from shared.geo import haversine_km, PILOT_CENTER_LAT, PILOT_CENTER_LNG, PILOT_RADIUS_KM
from services.dispatch_service import dispatch_service
from shared import redis_client
from firebase_admin import messaging
from datetime import datetime, timezone, timedelta
import uuid
import os
import logging
import hmac
import hashlib

logger = logging.getLogger(__name__)
router = APIRouter()

JOB_TIMEOUT_SECONDS = int(os.getenv("JOB_TIMEOUT_SECONDS", "120"))

# Helper for FCM
def _send_fcm_to_user(user_id: str, title: str, body: str, data: dict):
    try:
        result = supabase.table("users").select("fcm_token").eq("id", user_id).maybe_single().execute()
        if not result or not result.data:
            return
        fcm_token = result.data.get("fcm_token", "")
        if not fcm_token:
            return
        message = messaging.Message(
            token=fcm_token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            android=messaging.AndroidConfig(priority="high"),
        )
        messaging.send(message)
    except Exception as e:
        logger.warning(f"Failed to send FCM to user {user_id}: {e}")

def _send_silent_fcm(token: str, data: dict):
    try:
        if not token:
            return
        message = messaging.Message(
            token=token,
            data={k: str(v) for k, v in data.items()},
            android=messaging.AndroidConfig(priority="high"),
        )
        messaging.send(message)
    except Exception as e:
        logger.warning(f"Failed to send silent FCM: {e}")

# 1. Job Creation
@router.post("")
@router.post("/create")
def create_job(body: CreateJobRequest, background_tasks: BackgroundTasks, uid: str = Depends(verify_firebase_token)):
    # Geo-fence check
    distance = haversine_km(body.lat, body.lng, PILOT_CENTER_LAT, PILOT_CENTER_LNG)
    if distance > PILOT_RADIUS_KM:
        raise HTTPException(
            400,
            f"Location is {distance:.1f}km from Mysuru center. "
            f"Service available within {PILOT_RADIUS_KM}km radius only.",
        )

    job_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    status = "open"
    expires_at = (now + timedelta(minutes=10)).isoformat()

    # Look up employer's internal UUID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(404, "User not found")
    employer_id = user_result.data["id"]

    # Insert job (base fields that are guaranteed to exist)
    job_data = {
        "id": job_id,
        "employer_id": employer_id,
        "worker_id": None,
        "status": status,
        "skill_required": body.skill,
        "title": body.skill,
        "description": body.description,
        "location": f"POINT({body.lng} {body.lat})",
        "address": getattr(body, 'address', ''),
        "amount": body.budget,
        "payment_status": "pending",
        "scheduled_at": body.scheduled_at.isoformat() if body.scheduled_at else None,
    }
    supabase.table("jobs").insert(job_data).execute()

    # Try to update with emergency fields if columns exist
    try:
        emergency_fields = {}
        if body.job_type:
            emergency_fields["job_type"] = body.job_type
        if body.service_fee_type:
            emergency_fields["service_fee_type"] = body.service_fee_type
        if body.surcharge_amount:
            emergency_fields["surcharge_amount"] = body.surcharge_amount
        if emergency_fields:
            supabase.table("jobs").update(emergency_fields).eq("id", job_id).execute()
    except Exception as e:
        # Emergency columns may not exist in the table - that's OK
        print(f"[JOBS] Could not set emergency fields (columns may not exist): {e}")

    # Trigger Dispatch in background for immediate jobs
    if body.urgency != "scheduled":
        is_emergency = body.job_type == "emergency" if body.job_type else False
        background_tasks.add_task(
            dispatch_service.start_dispatch,
            job_id,
            uid,
            body.lat,
            body.lng,
            body.skill,
            is_emergency
        )

    return {
        "status": "ok",
        "job_id": job_id,
        "message": "Job created successfully",
    }

# 2. List Jobs
@router.get("")
def list_jobs(uid: str = Depends(verify_firebase_token)):
    # Resolve user id
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        return {"jobs": []}
    internal_id = user_result.data["id"]

    result = (supabase.table("jobs")
        .select("*")
        .eq("employer_id", internal_id)
        .order("created_at", desc=True)
        .limit(50)
        .execute())
    return {"jobs": result.data or []}

@router.get("/{job_id}")
def get_job(job_id: str, uid: str = Depends(verify_firebase_token)):
    result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not result or not result.data:
        raise HTTPException(404, "Job not found")

    job = dict(result.data)
    # Resolve internal user id
    user_result = supabase.table("users").select("id, role").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(403, "Not authorized to view this job")
    internal_id = user_result.data["id"]

    employer_id = job.get("employer_id")
    worker_id = job.get("worker_id")

    # Access control: only employer or assigned worker can access
    if internal_id != employer_id and internal_id != worker_id:
        raise HTTPException(403, "Not authorized to view this job")

    status = str(job.get("status") or "").lower()

    # Reveal contact info ONLY if job is accepted/matched/in_progress/completed
    if status in ("accepted", "matched", "in_progress", "completed"):
        if worker_id:
            try:
                w_user = supabase.table("users").select("name, phone").eq("id", worker_id).maybe_single().execute()
                if w_user and w_user.data:
                    job["worker_phone"] = w_user.data.get("phone") or ""
                    job["worker_name"] = w_user.data.get("name") or "Worker"
                else:
                    w_rec = supabase.table("workers").select("name, phone").eq("id", worker_id).maybe_single().execute()
                    if w_rec and w_rec.data:
                        job["worker_phone"] = w_rec.data.get("phone") or ""
                        job["worker_name"] = w_rec.data.get("name") or "Worker"
            except Exception as e:
                logger.warning(f"Failed to fetch worker contact details for job {job_id}: {e}")

        if employer_id:
            try:
                e_user = supabase.table("users").select("name, phone").eq("id", employer_id).maybe_single().execute()
                if e_user and e_user.data:
                    job["employer_phone"] = e_user.data.get("phone") or ""
                    job["customer_phone"] = e_user.data.get("phone") or ""
                    job["employer_name"] = e_user.data.get("name") or "Employer"
            except Exception as e:
                logger.warning(f"Failed to fetch employer contact details for job {job_id}: {e}")

    return job


def _perform_cancel_job(job_id: str, uid: str):
    CANCELLABLE = {"open", "searching", "matched"}

    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(404, "User not found")
    employer_id = user_result.data["id"]

    result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not result or not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    if job.get("employer_id") != employer_id:
        raise HTTPException(403, "Not authorized to cancel this job")
    if job.get("status") not in CANCELLABLE:
        raise HTTPException(400, f"Cannot cancel job in status '{job.get('status')}'")

    supabase.table("jobs").update({
        "status": "cancelled",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    return {"status": "ok", "message": "Job cancelled"}

@router.post("/{job_id}/cancel")
def cancel_job_post(job_id: str, uid: str = Depends(verify_firebase_token)):
    return _perform_cancel_job(job_id, uid)

@router.delete("/{job_id}")
def cancel_job_delete(job_id: str, uid: str = Depends(verify_firebase_token)):
    return _perform_cancel_job(job_id, uid)

# 5. Accept Job
@router.post("/{job_id}/accept")
def accept_job(job_id: str, body: AcceptJobRequest, uid: str = Depends(verify_firebase_token)):
    lock_key = f"lock:job:{job_id}"
    acquired = redis_client.acquire_lock(lock_key, body.worker_id, ex=10)
    if not acquired:
        raise HTTPException(status_code=409, detail="Job already accepted")

    try:
        job_result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
        if not job_result or not job_result.data:
            raise HTTPException(404, "Job not found")

        job = job_result.data
        if job.get("status") not in ("open", "searching", "matched"):
            raise HTTPException(409, f"Job is no longer available (status: {job.get('status')})")

        worker_user = supabase.table("users").select("id, name, phone, fcm_token").eq("firebase_uid", body.worker_id).maybe_single().execute()
        worker_info = (worker_user.data if worker_user else None) or {}
        worker_uuid = worker_info.get("id")

        # Atomic update with RPC
        try:
            accept_result = supabase.rpc("accept_job_atomic", {
                "p_job_id": job_id,
                "p_worker_id": str(worker_uuid),
            }).execute()
            is_accepted = accept_result.data
        except Exception:
            # Fallback direct update
            supabase.table("jobs").update({
                "worker_id": worker_uuid,
                "status": "accepted",
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "accepted_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", job_id).execute()
            # Mark worker as unavailable
            try:
                supabase.table("workers").update({
                    "is_available": False,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", worker_uuid).execute()
            except Exception as w_err:
                logger.warning(f"Failed to mark worker unavailable in fallback direct update: {w_err}")
            is_accepted = True

        if is_accepted is False:
            raise HTTPException(status_code=409, detail="Job already accepted")

        # Determine and lock the agreed price
        agreed_price = body.agreed_price
        if agreed_price is None:
            worker_rate_result = supabase.table("workers").select("rate_per_hour").eq("id", worker_uuid).maybe_single().execute()
            rate = (worker_rate_result.data or {}).get("rate_per_hour")
            if rate is not None:
                agreed_price = float(rate)
            else:
                agreed_price = float(job.get("amount") or 150.0)

        # Save agreed price on the job
        supabase.table("jobs").update({
            "agreed_price": agreed_price,
            "amount": agreed_price,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", job_id).execute()

        # Schedule QStash pre-arrival check
        try:
            from shared.models import IST
            from shared.qstash import enqueue_task
            now_ist = datetime.now(IST)
            scheduled_at_str = job.get("scheduled_at")
            
            if scheduled_at_str:
                scheduled_at = datetime.fromisoformat(scheduled_at_str.replace("Z", "+00:00")).astimezone(IST)
                check_time = scheduled_at - timedelta(minutes=10)
            else:
                check_time = now_ist + timedelta(minutes=20)
                
            delay_seconds = int((check_time - now_ist).total_seconds())
            if delay_seconds < 0:
                delay_seconds = 5
                
            task_id = enqueue_task(
                url="/v1/jobs/pre-arrival-check",
                body={"job_id": job_id, "worker_id": body.worker_id},
                delay_seconds=delay_seconds
            )
            logger.info(f"Antigravity: Scheduled pre-arrival check for job {job_id} in {delay_seconds} seconds. Task ID: {task_id}")
        except Exception as qstash_err:
            logger.error(f"Antigravity: Failed to schedule QStash pre-arrival check: {qstash_err}")

        # Send FCM to customer
        employer_id = job.get("employer_id")
        if employer_id:
            _send_fcm_to_user(
                employer_id,
                title="Worker Found!",
                body=f"{worker_info.get('name', 'A worker')} is on the way",
                data={
                    "type": "WORKER_ASSIGNED",
                    "job_id": job_id,
                    "worker_name": worker_info.get("name", "Worker"),
                    "worker_phone": worker_info.get("phone", ""),
                },
            )
            # Direct DB notification insert for local test reliability
            try:
                supabase.table("notifications").insert({
                    "user_id": employer_id,
                    "job_id": job_id,
                    "type": "WORKER_ASSIGNED",
                    "title": "Worker Found!",
                    "body": f"{worker_info.get('name', 'A worker')} is on the way",
                    "data": {
                        "type": "WORKER_ASSIGNED",
                        "job_id": job_id,
                        "worker_name": worker_info.get("name", "Worker"),
                        "worker_phone": worker_info.get("phone", ""),
                    },
                    "sent": True
                }).execute()
                logger.info(f"Direct DB notification inserted for employer_id: {employer_id}")
            except Exception as notify_err:
                logger.warning(f"Failed to insert direct notification to DB: {notify_err}")

        # Notify other workers
        try:
            notified = redis_client.count_by_pattern(f"job_notified:{job_id}:*")
            for redis_key in notified:
                other_worker_id = redis_key.split(":")[-1]
                if other_worker_id == str(worker_uuid):
                    continue
                try:
                    other_user = supabase.table("users").select("fcm_token").eq("id", other_worker_id).maybe_single().execute()
                    other_token = ((other_user.data if other_user else None) or {}).get("fcm_token", "")
                    if other_token:
                        _send_silent_fcm(other_token, {
                            "type": "JOB_TAKEN",
                            "job_id": job_id,
                            "message": "Another worker accepted this job",
                        })
                except Exception:
                    pass
                redis_client.release_lock(redis_key)
        except Exception as e:
            logger.warning(f"Error notifying other workers: {e}")

        return {
            "status": "ok",
            "job_id": job_id,
            "message": "Job accepted.",
        }

    finally:
        redis_client.release_lock(lock_key)

# 6. Reject Job
@router.post("/{job_id}/reject")
def reject_job(job_id: str, body: RejectJobRequest, uid: str = Depends(verify_firebase_token)):
    redis_key = f"job_notified:{job_id}:{body.worker_id}"
    redis_client.set_state(redis_key, "rejected", ex=300)
    return {"status": "rejected", "job_id": job_id}

# 7. Acknowledge Job (Worker confirms arrival)
@router.post("/{job_id}/ack")
def ack_job(job_id: str, uid: str = Depends(verify_firebase_token)):
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(404, "User not found")
    worker_uuid = user_result.data["id"]

    result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not result or not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    if job.get("worker_id") != worker_uuid:
        raise HTTPException(403, "Not the assigned worker")
    if job.get("status") != "accepted":
        raise HTTPException(409, f"Cannot acknowledge job in status '{job.get('status')}'")

    supabase.table("jobs").update({
        "status": "in_progress",
        "started_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    return {"status": "ok", "job_id": job_id}

# 8. Complete Job
@router.post("/{job_id}/complete")
def complete_job(job_id: str, body: CompleteJobRequest, uid: str = Depends(verify_firebase_token)):
    result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not result or not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    if job.get("status") not in ("in_progress", "accepted"):
        raise HTTPException(400, f"Cannot complete job in status '{job.get('status')}'")

    # Update completion status
    supabase.table("jobs").update({
        "status": "completed",
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    worker_id = job.get("worker_id")
    if worker_id:
        supabase.table("workers").update({
            "is_available": True,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", worker_id).execute()
        
        try:
            supabase.rpc("increment_worker_total_jobs", {"p_worker_id": worker_id}).execute()
        except Exception:
            pass

    # Notify customer
    employer_id = job.get("employer_id")
    if employer_id:
        _send_fcm_to_user(
            employer_id,
            title="Job Completed! ✅",
            body="Your job has been marked as completed.",
            data={"type": "JOB_COMPLETED", "job_id": job_id},
        )

    return {"status": "completed", "job_id": job_id}

# 9. Review Job
class JobReviewRequest(BaseModel):
    rating: float
    comment: str | None = None

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v):
        if not (1.0 <= v <= 5.0):
            raise ValueError("Rating must be between 1.0 and 5.0")
        return v

@router.post("/{job_id}/review")
def review_job(job_id: str, body: JobReviewRequest, uid: str = Depends(verify_firebase_token)):
    result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not result or not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    worker_id = job.get("worker_id")
    if not worker_id:
        raise HTTPException(400, "No worker assigned to this job")

    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(404, "User not found")
    reviewer_id = user_result.data["id"]

    if job.get("employer_id") != reviewer_id:
        raise HTTPException(403, "Only the customer who created this job can review it")

    try:
        supabase.rpc("submit_review_atomic", {
            "p_job_id": job_id,
            "p_reviewer_id": str(reviewer_id),
            "p_reviewee_id": str(worker_id),
            "p_rating": int(body.rating),
            "p_comment": body.comment,
        }).execute()
    except Exception as rpc_err:
        logger.warning(f"submit_review_atomic RPC failed, using fallback: {rpc_err}")
        # Fallback to direct reviews table insertion
        try:
            supabase.table("reviews").insert({
                "job_id": job_id,
                "reviewer_id": reviewer_id,
                "reviewee_id": worker_id,
                "rating": body.rating,
                "comment": body.comment,
            }).execute()
            # Recalculate worker aggregate rating
            revs = supabase.table("reviews").select("rating").eq("reviewee_id", worker_id).execute()
            if revs and revs.data:
                ratings = [r["rating"] for r in revs.data if r.get("rating") is not None]
                if ratings:
                    avg_rating = round(sum(ratings) / float(len(ratings)), 2)
                    supabase.table("workers").update({"rating": avg_rating}).eq("id", worker_id).execute()
        except Exception as e:
            logger.error(f"Fallback review failed: {e}")

    return {"status": "success", "message": "Review submitted"}


@router.get("/worker/history")
def get_worker_job_history(uid: str = Depends(verify_firebase_token)):
    """
    Returns past job lifecycle history for the logged-in worker,
    including status, agreed price / amount, completed_at, customer name, and rating received.
    """
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(404, "Worker user not found")
    worker_uuid = user_result.data["id"]

    res = (supabase.table("jobs")
        .select("*")
        .eq("worker_id", worker_uuid)
        .order("created_at", desc=True)
        .limit(50)
        .execute())

    jobs_list = res.data or []
    formatted = []
    for job in jobs_list:
        employer_name = "Customer"
        if job.get("employer_id"):
            try:
                emp_res = supabase.table("users").select("name").eq("id", job["employer_id"]).maybe_single().execute()
                if emp_res and emp_res.data and emp_res.data.get("name"):
                    employer_name = emp_res.data["name"]
            except Exception:
                pass
        
        rating_received = None
        comment_received = None
        try:
            rev_res = supabase.table("reviews").select("rating, comment").eq("job_id", job["id"]).maybe_single().execute()
            if rev_res and rev_res.data:
                rating_received = rev_res.data.get("rating")
                comment_received = rev_res.data.get("comment")
        except Exception:
            pass

        formatted.append({
            "id": job["id"],
            "title": job.get("title") or job.get("skill_required") or "Service Job",
            "skill_required": job.get("skill_required") or "",
            "status": job.get("status") or "unknown",
            "amount": float(job.get("agreed_price") or job.get("amount") or 0.0),
            "address": job.get("address") or "",
            "created_at": job.get("created_at"),
            "accepted_at": job.get("accepted_at"),
            "completed_at": job.get("completed_at"),
            "employer_name": employer_name,
            "rating_received": rating_received,
            "comment_received": comment_received,
        })

    return {"jobs": formatted}


# 10. Create Payment Order (Razorpay)
@router.post("/{job_id}/create-order")
def create_order(job_id: str, uid: str = Depends(verify_firebase_token)):
    result = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not result or not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    amount_rupees = job.get("amount", 0) or 500.0
    amount_paise = int(amount_rupees * 100)

    key_id = os.getenv("RAZORPAY_KEY_ID", "")
    key_secret = os.getenv("RAZORPAY_KEY_SECRET", "")

    simulated_order_id = f"order_{uuid.uuid4().hex[:12]}"

    if not key_id or not key_secret or key_id == "rzp_test_placeholder_key_id":
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
            logger.warning(f"Razorpay creation failed: {e}")
            order_data = {
                "id": simulated_order_id, "amount": amount_paise,
                "currency": "INR", "status": "created", "simulated": True,
            }

    # Store order reference
    supabase.table("jobs").update({
        "razorpay_order_id": order_data["id"],
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    return order_data


# ─── ANTIGRAVITY: NO-SHOW PROTECTION WEBHOOKS ───────────────────

# Helper to decode job coordinates (ST_Y, ST_X) or from location dictionary
def _get_job_coords(job_id: str, job_dict: dict) -> tuple[float, float]:
    loc = job_dict.get("location")
    if isinstance(loc, dict) and loc.get("type") == "Point":
        coords = loc.get("coordinates")
        if len(coords) == 2:
            return float(coords[1]), float(coords[0]) # lat, lng
            
    try:
        coord_res = supabase.rpc("get_job_coordinates", {"p_job_id": job_id}).execute()
        if coord_res.data:
            c = coord_res.data[0]
            return float(c["lat"]), float(c["lng"])
    except Exception as e:
        logger.warning(f"Failed to get coordinates via RPC: {e}")
        
    return PILOT_CENTER_LAT, PILOT_CENTER_LNG


class PreArrivalCheckPayload(BaseModel):
    job_id: str
    worker_id: str


@router.post("/pre-arrival-check")
def pre_arrival_check(body: PreArrivalCheckPayload):
    """
    QStash webhook endpoint. Fires 10 mins before agreed arrival time.
    Sends FCM ping to worker asking to confirm they're on the way.
    Schedules the timeout check in 5 minutes (300 seconds).
    """
    job_id = body.job_id
    worker_id = body.worker_id
    
    # 1. Fetch current job status
    job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        logger.info(f"Pre-arrival-check: Job {job_id} not found. Skipping.")
        return {"status": "skipped", "reason": "job_not_found"}
        
    job = job_res.data
    # If the job status is not 'accepted', the worker or customer has cancelled, or it is completed
    if job.get("status") != "accepted":
        logger.info(f"Pre-arrival-check: Job {job_id} status is '{job.get('status')}', not 'accepted'. Skipping check.")
        return {"status": "skipped", "reason": f"invalid_job_status_{job.get('status')}"}
        
    # Check if pre-arrival check already ran (idempotency check)
    if job.get("pre_arrival_checked_at") is not None:
        logger.info(f"Pre-arrival-check: Check already executed for job {job_id}. Skipping.")
        return {"status": "skipped", "reason": "already_checked"}
        
    # Mark checked_at in database
    now_str = datetime.now(timezone.utc).isoformat()
    supabase.table("jobs").update({
        "pre_arrival_checked_at": now_str,
        "updated_at": now_str
    }).eq("id", job_id).execute()
    
    # 2. Get worker info (fcm_token)
    worker_res = supabase.table("users").select("fcm_token, name").eq("id", worker_id).maybe_single().execute()
    worker = worker_res.data or {}
    token = worker.get("fcm_token")
    
    # Send FCM ping
    if token:
        try:
            message = messaging.Message(
                token=token,
                notification=messaging.Notification(
                    title="Confirm you are on the way! 🚨",
                    body="You have a job starting in 10 minutes. Tap to confirm."
                ),
                data={
                    "type": "PRE_ARRIVAL_PING",
                    "job_id": job_id,
                    "action": "confirm_on_the_way"
                },
                android=messaging.AndroidConfig(priority="high"),
            )
            messaging.send(message)
            logger.info(f"Sent pre-arrival FCM check to worker {worker_id} for job {job_id}")
        except Exception as e:
            logger.warning(f"Failed to send pre-arrival FCM to worker: {e}")
            
    # 3. Schedule the reassignment timeout check in 5 minutes (300 seconds)
    from shared.qstash import enqueue_task
    timeout_task_id = enqueue_task(
        url="/v1/jobs/reassignment-check",
        body={"job_id": job_id, "worker_id": worker_id},
        delay_seconds=300
    )
    logger.info(f"Scheduled reassignment check for job {job_id} in 300 seconds. Task ID: {timeout_task_id}")
    
    return {"status": "success", "message": "Pre-arrival check sent"}


@router.post("/{job_id}/confirm-on-the-way")
@router.patch("/{job_id}/confirm-on-the-way")
def confirm_on_the_way(job_id: str, uid: str = Depends(verify_firebase_token)):
    """
    Worker confirms they are on the way.
    Sets jobs.on_the_way_confirmed_at = now()
    """
    # 1. Resolve worker UUID
    user_res = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_res or not user_res.data:
        raise HTTPException(404, "Worker user not found")
    worker_uuid = user_res.data["id"]
    
    # 2. Verify job ownership
    job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        raise HTTPException(404, "Job not found")
        
    job = job_res.data
    # Check if this is the assigned worker
    if str(job.get("worker_id")) != str(worker_uuid):
        raise HTTPException(403, "Not authorized: not the assigned worker")
        
    if job.get("status") != "accepted":
        raise HTTPException(400, f"Cannot confirm on-the-way for job in state '{job.get('status')}'")
        
    # Update confirmation timestamp
    now_str = datetime.now(timezone.utc).isoformat()
    supabase.table("jobs").update({
        "on_the_way_confirmed_at": now_str,
        "updated_at": now_str
    }).eq("id", job_id).execute()
    
    logger.info(f"Worker {worker_uuid} confirmed on-the-way for job {job_id}")
    return {"status": "ok", "message": "On-the-way status confirmed"}


class ReassignmentCheckPayload(BaseModel):
    job_id: str
    worker_id: str  # Original worker Firebase UID


@router.post("/reassignment-check")
def reassignment_check(body: ReassignmentCheckPayload, background_tasks: BackgroundTasks):
    """
    QStash webhook endpoint. Fires 5 mins after pre-arrival check.
    If worker failed to confirm they are on the way, mark as no-show,
    reassign to next closest worker, and notify customer.
    """
    job_id = body.job_id
    worker_firebase_uid = body.worker_id
    
    # 1. Acquire Redis distributed lock
    lock_key = f"lock:reassign:{job_id}"
    acquired = redis_client.acquire_lock(lock_key, worker_firebase_uid, ex=30)
    if not acquired:
        logger.info(f"Reassignment check: Lock already held for job {job_id}. Skipping.")
        return {"status": "skipped", "reason": "lock_already_held"}
        
    try:
        # Resolve internal worker UUID
        user_res = supabase.table("users").select("id").eq("firebase_uid", worker_firebase_uid).maybe_single().execute()
        if not user_res or not user_res.data:
            logger.warning(f"Reassignment check: Worker firebase_uid {worker_firebase_uid} not found. Skipping.")
            return {"status": "skipped", "reason": "worker_not_found"}
        internal_worker_uuid = user_res.data["id"]

        # 2. Fetch current job status
        job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
        if not job_res or not job_res.data:
            logger.info(f"Reassignment check: Job {job_id} not found. Skipping.")
            return {"status": "skipped", "reason": "job_not_found"}
            
        job = job_res.data
        
        # Verify job is still assigned to the SAME worker and status is accepted
        if str(job.get("worker_id")) != str(internal_worker_uuid):
            logger.info(f"Reassignment check: Worker changed (current: {job.get('worker_id')}, check target: {internal_worker_uuid}). Skipping.")
            return {"status": "skipped", "reason": "worker_changed"}
            
        if job.get("status") != "accepted":
            logger.info(f"Reassignment check: Job status is '{job.get('status')}', not 'accepted'. Skipping.")
            return {"status": "skipped", "reason": "job_not_accepted"}
            
        # 3. Check if worker confirmed they are on the way
        if job.get("on_the_way_confirmed_at") is not None:
            logger.info(f"Reassignment check: Worker confirmed on-the-way. No action needed.")
            return {"status": "success", "reason": "already_confirmed"}
            
        # ─── WORKER HAS NO-SHOWED ───
        logger.info(f"🚨 Worker {internal_worker_uuid} failed to confirm pre-arrival check for job {job_id}. Triggering no-show reassignment.")
        now_str = datetime.now(timezone.utc).isoformat()
        
        # 4. Increment strikes on worker
        w_res = supabase.table("workers").select("strikes").eq("id", internal_worker_uuid).maybe_single().execute()
        current_strikes = (w_res.data or {}).get("strikes", 0) or 0
        new_strikes = current_strikes + 1
        
        update_worker_data = {
            "strikes": new_strikes,
            "last_strike_at": now_str,
            "updated_at": now_str
        }
        
        # Check suspension threshold
        is_suspended = new_strikes >= 3
        if is_suspended:
            update_worker_data["suspended"] = True
            update_worker_data["approval_status"] = "suspended"
            update_worker_data["is_available"] = False
            update_worker_data["is_online"] = False
            
        supabase.table("workers").update(update_worker_data).eq("id", internal_worker_uuid).execute()
        
        # Send strike alert FCM to worker
        try:
            worker_user_res = supabase.table("users").select("fcm_token").eq("id", internal_worker_uuid).maybe_single().execute()
            worker_token = (worker_user_res.data or {}).get("fcm_token")
            if worker_token:
                if is_suspended:
                    title = "Account Suspended 🚫"
                    body = "Your worker account has been suspended due to 3 no-show strikes."
                else:
                    title = f"No-Show Strike Added! ({new_strikes}/3) ⚠️"
                    body = f"You failed to confirm you are on the way. Strike added. Account will be suspended at 3 strikes."
                    
                message = messaging.Message(
                    token=worker_token,
                    notification=messaging.Notification(title=title, body=body),
                    data={"type": "STRIKE_ALERT", "strikes": str(new_strikes), "suspended": str(is_suspended)},
                    android=messaging.AndroidConfig(priority="high"),
                )
                messaging.send(message)
        except Exception as fcm_err:
            logger.warning(f"Failed to send strike FCM to worker: {fcm_err}")

        # 5. Cancel original worker's active job assignment
        supabase.table("jobs").update({
            "worker_id": None,
            "status": "searching",
            "no_show_at": now_str,
            "on_the_way_confirmed_at": None,
            "pre_arrival_checked_at": None,
            "version": job.get("version", 1) + 1,
            "updated_at": now_str
        }).eq("id", job_id).execute()
        
        # Free up original worker's availability if NOT suspended
        if not is_suspended:
            supabase.table("workers").update({
                "is_available": True,
                "updated_at": now_str
            }).eq("id", internal_worker_uuid).execute()

        # 6. Notify Customer
        employer_id = job.get("employer_id")
        if employer_id:
            _send_fcm_to_user(
                employer_id,
                title="Finding a new worker... 🚨",
                body="Your previous worker couldn't make it. We are searching for a replacement immediately.",
                data={
                    "type": "WORKER_NOSHOW",
                    "job_id": job_id,
                },
            )

        # 7. Trigger PostGIS search for next nearest available worker in the background
        lat, lng = _get_job_coords(job_id, job)
        background_tasks.add_task(
            dispatch_service.start_dispatch,
            job_id,
            employer_id,
            lat,
            lng,
            job.get("skill_required"),
            job.get("job_type") == "emergency"
        )
        
        return {"status": "reassigned", "job_id": job_id, "original_worker": internal_worker_uuid, "new_strikes": new_strikes}
        
    finally:
        redis_client.release_lock(lock_key)


# ─── Price Lock / Change Request Endpoints ───────────────────────

from shared.models import PriceChangeRequestInput, PriceChangeResponseInput

@router.post("/{job_id}/price-change")
def request_price_change(job_id: str, body: PriceChangeRequestInput, uid: str = Depends(verify_firebase_token)):
    """
    Worker requests a price change mid-job.
    Creates a pending price change request in Supabase and pings the customer.
    """
    # 1. Resolve worker internal UUID
    user_res = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_res or not user_res.data:
        raise HTTPException(404, "Worker user not found")
    worker_uuid = user_res.data["id"]

    # 2. Verify job ownership and status
    job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        raise HTTPException(404, "Job not found")
    job = job_res.data

    if str(job.get("worker_id")) != str(worker_uuid):
        raise HTTPException(403, "Not authorized: you are not the assigned worker for this job")

    if job.get("status") not in ("accepted", "in_progress"):
        raise HTTPException(400, f"Cannot request price change for job in status '{job.get('status')}'")

    # 3. Check for existing pending request
    existing = supabase.table("price_change_requests").select("id").eq("job_id", job_id).eq("status", "pending").execute()
    if existing.data:
        raise HTTPException(409, "A price change request is already pending approval for this job")

    old_price = float(job.get("agreed_price") or job.get("amount") or 0.0)

    # 4. Insert request
    req_id = str(uuid.uuid4())
    supabase.table("price_change_requests").insert({
        "id": req_id,
        "job_id": job_id,
        "worker_id": worker_uuid,
        "old_price": old_price,
        "new_price": body.new_price,
        "reason": body.reason,
        "status": "pending"
    }).execute()

    # 5. Send FCM to customer
    employer_id = job.get("employer_id")
    if employer_id:
        _send_fcm_to_user(
            employer_id,
            title="Price Change Request 💰",
            body=f"Worker requested to change price from ₹{old_price:.0f} to ₹{body.new_price:.0f} (Reason: {body.reason})",
            data={
                "type": "PRICE_CHANGE_REQUESTED",
                "job_id": job_id,
                "request_id": req_id,
                "old_price": str(old_price),
                "new_price": str(body.new_price),
                "reason": body.reason
            }
        )

    logger.info(f"Price change request created by worker {worker_uuid} for job {job_id}: old={old_price}, new={body.new_price}")
    return {"status": "ok", "request_id": req_id, "message": "Price change request sent to customer"}


@router.post("/{job_id}/price-change/respond")
def respond_price_change(job_id: str, body: PriceChangeResponseInput, uid: str = Depends(verify_firebase_token)):
    """
    Customer approves or rejects a pending price change request.
    If approved, locks the new price in agreed_price and amount.
    """
    # 1. Resolve customer internal UUID
    user_res = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_res or not user_res.data:
        raise HTTPException(404, "Customer user not found")
    customer_uuid = user_res.data["id"]

    # 2. Verify job ownership
    job_res = supabase.table("jobs").select("*").eq("id", job_id).maybe_single().execute()
    if not job_res or not job_res.data:
        raise HTTPException(404, "Job not found")
    job = job_res.data

    if str(job.get("employer_id")) != str(customer_uuid):
        raise HTTPException(403, "Not authorized: you are not the owner of this job")

    # 3. Find pending request
    req_res = supabase.table("price_change_requests").select("*").eq("job_id", job_id).eq("status", "pending").maybe_single().execute()
    if not req_res or not req_res.data:
        raise HTTPException(404, "No pending price change request found for this job")
    req = req_res.data
    req_id = req["id"]
    new_price = float(req["new_price"])
    worker_uuid = req["worker_id"]

    now_str = datetime.now(timezone.utc).isoformat()
    status_str = "approved" if body.approved else "rejected"

    # 4. Update request status
    supabase.table("price_change_requests").update({
        "status": status_str,
        "updated_at": now_str
    }).eq("id", req_id).execute()

    # 5. Handle approval
    if body.approved:
        # Update price on job
        supabase.table("jobs").update({
            "agreed_price": new_price,
            "amount": new_price,
            "version": job.get("version", 1) + 1,
            "updated_at": now_str
        }).eq("id", job_id).execute()
        
        logger.info(f"Price change request approved for job {job_id}. Price updated to {new_price}")
    else:
        logger.info(f"Price change request rejected for job {job_id}. Price remains at {job.get('agreed_price')}")

    # 6. Notify worker
    try:
        worker_user_res = supabase.table("users").select("fcm_token").eq("id", worker_uuid).maybe_single().execute()
        worker_token = (worker_user_res.data or {}).get("fcm_token")
        if worker_token:
            if body.approved:
                title = "Price Change Approved! ✅"
                body_msg = f"Customer approved the price change to ₹{new_price:.0f}."
            else:
                title = "Price Change Rejected ❌"
                body_msg = "Customer rejected your price change request."
                
            message = messaging.Message(
                token=worker_token,
                notification=messaging.Notification(title=title, body=body_msg),
                data={"type": "PRICE_CHANGE_RESPONDED", "job_id": job_id, "approved": str(body.approved), "new_price": str(new_price)},
                android=messaging.AndroidConfig(priority="high"),
            )
            messaging.send(message)
    except Exception as fcm_err:
        logger.warning(f"Failed to send price change response FCM: {fcm_err}")

    return {"status": "ok", "price_change_status": status_str, "agreed_price": new_price if body.approved else job.get("agreed_price")}


# ─── Master Prompt v1 — Sequential Job Notification Layer ─────────

async def notify_next_worker(job_request_id: str):
    """
    Internal function to notify the next nearest worker in sequence for a job_request.
    Idempotent guard: aborts if job status is no longer pending/notifying.
    """
    # 1. Fetch job_request
    res = supabase.table("job_requests").select("*").eq("id", job_request_id).maybe_single().execute()
    if not res or not res.data:
        logger.warning(f"notify_next_worker: job_request {job_request_id} not found")
        return
    job_req = res.data
    status = job_req.get("status")

    # Idempotency guard: abort if no longer pending or notifying
    if status not in ("pending", "notifying"):
        logger.info(f"notify_next_worker: job_request {job_request_id} in state '{status}', aborting notification sequence.")
        return

    # 2. Get candidate list & index from Redis
    r = redis_client.get_client()
    cache_key = f"cache:job_request:{job_request_id}:candidates"
    candidates_data = None
    if r:
        try:
            raw = r.get(cache_key)
            if raw:
                candidates_data = json.loads(raw)
        except Exception as e:
            logger.error(f"Redis get candidates error: {e}")

    if not candidates_data:
        logger.warning(f"notify_next_worker: candidates missing for job {job_request_id}")
        supabase.table("job_requests").update({"status": "rejected_all", "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", job_request_id).execute()
        _send_fcm_to_user(job_req["user_id"], "No workers available", "No workers available right now, please try again.", {"type": "job_request_update", "status": "rejected_all", "job_request_id": job_request_id})
        return

    candidates = candidates_data.get("candidates", [])
    current_index = candidates_data.get("current_index", 0)

    # 3. If no candidates left -> rejected_all
    if current_index >= len(candidates):
        logger.info(f"notify_next_worker: exhausted all {len(candidates)} candidates for job {job_request_id}")
        supabase.table("job_requests").update({"status": "rejected_all", "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", job_request_id).execute()
        _send_fcm_to_user(job_req["user_id"], "No workers available", "No workers available right now, please try again.", {"type": "job_request_update", "status": "rejected_all", "job_request_id": job_request_id})
        return

    # 4. Pop next worker
    target_worker_id = candidates[current_index]
    attempt_order = current_index + 1

    # Update index in Redis
    candidates_data["current_index"] = current_index + 1
    if r:
        try:
            r.set(cache_key, json.dumps(candidates_data), ex=600)
        except Exception as e:
            logger.error(f"Redis set candidates error: {e}")

    # 5. Insert job_notification_attempts row
    try:
        supabase.table("job_notification_attempts").insert({
            "job_request_id": job_request_id,
            "worker_id": target_worker_id,
            "attempt_order": attempt_order,
            "status": "sent",
            "sent_at": datetime.now(timezone.utc).isoformat()
        }).execute()
    except Exception as err:
        logger.warning(f"Error inserting job_notification_attempt for worker {target_worker_id}: {err}")

    # 6. Fetch worker FCM token
    worker_res = supabase.table("workers").select("fcm_token").eq("id", target_worker_id).maybe_single().execute()
    fcm_token = (worker_res.data or {}).get("fcm_token") if worker_res else None

    service_type = job_req.get("service_type", "Service")

    # 7. Update status to notifying
    supabase.table("job_requests").update({"status": "notifying", "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", job_request_id).execute()

    # 8. Send FCM push to worker
    if fcm_token:
        try:
            offer_expires_at = (datetime.now(timezone.utc) + timedelta(seconds=30)).isoformat()
            data_payload = {
                "type": "job_offer",
                "job_request_id": str(job_request_id),
                "service_type": str(service_type),
                "offer_expires_at": str(offer_expires_at)
            }
            message = messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(
                    title="New job nearby 🔧",
                    body=f"{service_type} needed nearby"
                ),
                data=data_payload,
                android=messaging.AndroidConfig(priority="high"),
            )
            messaging.send(message)
            logger.info(f"Sent job_offer FCM to worker {target_worker_id} for job {job_request_id}")
        except Exception as fcm_err:
            logger.warning(f"Failed to send FCM to worker {target_worker_id}: {fcm_err}")

    # 9. Schedule timeout via QStash / local task in 30 seconds
    try:
        from shared.qstash import enqueue_task
        enqueue_task(
            url=f"jobs/{job_request_id}/timeout-check?worker_id={target_worker_id}",
            body={"job_request_id": job_request_id, "worker_id": target_worker_id, "attempt_order": attempt_order},
            delay_seconds=30
        )
    except Exception as q_err:
        logger.warning(f"Failed to schedule timeout for worker {target_worker_id}: {q_err}")


@router.post("/request", response_model=JobRequestResponse)
async def request_job(body: JobRequestCreate):
    """
    Triggered when a user taps 'Request Worker'.
    Creates a job_requests row, queries PostGIS nearest workers (is_available=true & valid fcm_token),
    caches candidate list in Redis, and notifies the first candidate worker.
    """
    job_request_id = str(uuid.uuid4())
    now_str = datetime.now(timezone.utc).isoformat()

    # 1. Create job_requests row (status=pending)
    job_req_data = {
        "id": job_request_id,
        "user_id": body.user_id,
        "service_type": body.service_type,
        "status": "pending",
        "job_location": f"POINT({body.lng} {body.lat})",
        "created_at": now_str,
        "updated_at": now_str
    }

    try:
        supabase.table("job_requests").insert(job_req_data).execute()
    except Exception as db_err:
        logger.error(f"Failed to insert job_requests row: {db_err}")
        raise HTTPException(500, detail="Database insert failed")

    # 2. Call existing PostGIS nearest worker search logic
    candidate_worker_ids = []
    try:
        for radius_m in [3000, 5000, 10000]:
            rpc_res = supabase.rpc("find_nearby_workers", {
                "lat": body.lat,
                "lng": body.lng,
                "skill": body.service_type.lower(),
                "radius_meters": radius_m
            }).execute()

            raw_workers = rpc_res.data or []
            if raw_workers:
                w_ids = [str(w["id"]) for w in raw_workers if "id" in w]
                if w_ids:
                    st_res = supabase.table("workers").select("id, is_available, fcm_token").in_("id", w_ids).execute()
                    avail_workers = {
                        str(w["id"]): w for w in (st_res.data or [])
                        if w.get("is_available") is not False and w.get("fcm_token")
                    }
                    candidate_worker_ids = [wid for wid in w_ids if wid in avail_workers]
                    if candidate_worker_ids:
                        break
    except Exception as search_err:
        logger.error(f"PostGIS search error during job request: {search_err}")

    # Fallback to direct query if RPC returned empty or failed
    if not candidate_worker_ids:
        try:
            db_res = supabase.table("workers").select("id, is_available, fcm_token").execute()
            candidate_worker_ids = [
                str(w["id"]) for w in (db_res.data or [])
                if w.get("is_available") is not False and w.get("fcm_token")
            ]
        except Exception as e:
            logger.error(f"Fallback worker lookup error: {e}")

    # 3. If no candidate workers found
    if not candidate_worker_ids:
        supabase.table("job_requests").update({"status": "expired", "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", job_request_id).execute()
        raise HTTPException(status_code=404, detail="No available workers nearby right now.")

    # 4. Cache candidates in Redis with 10 min TTL
    r = redis_client.get_client()
    cache_key = f"cache:job_request:{job_request_id}:candidates"
    if r:
        try:
            r.set(cache_key, json.dumps({"candidates": candidate_worker_ids, "current_index": 0}), ex=600)
        except Exception as cache_err:
            logger.error(f"Redis cache error for candidates: {cache_err}")

    # 5. Notify the first candidate worker
    await notify_next_worker(job_request_id)

    return JobRequestResponse(
        job_request_id=job_request_id,
        status="notifying",
        message="Job request created. Notifying candidate worker."
    )


def _safe_rpc_jsonb(rpc_name: str, params: dict) -> dict | None:
    """
    Safely call a Supabase RPC that returns JSONB containing a 'message' key.

    The Supabase Python client (postgrest-py) has a Pydantic validator that
    treats any dict response with a 'message' key as an API error, crashing
    with: "You are passing an API error to the data field."

    This helper catches that exception and extracts the actual JSONB data from the
    exception's 'details' field.
    """
    try:
        res = supabase.rpc(rpc_name, params).execute()
        if res and res.data:
            return res.data
        return None
    except Exception as e:
        d = str(getattr(e, "details", ""))
        if d.startswith("b'") and d.endswith("'"):
            try:
                return json.loads(d[2:-1])
            except Exception:
                pass
        elif d.startswith('b"') and d.endswith('"'):
            try:
                return json.loads(d[2:-1])
            except Exception:
                pass
        raise


@router.post("/{job_request_id}/respond")
async def respond_to_job_request(job_request_id: str, body: JobRespondRequest):
    """
    3.3 Worker taps Accept or Reject.
    Must handle race condition: row lock & status check via SELECT ... FOR UPDATE transaction.
    """
    now_str = datetime.now(timezone.utc).isoformat()

    # 0. Try DB Transaction RPC with SELECT ... FOR UPDATE row locking
    try:
        tx_data = _safe_rpc_jsonb("respond_to_job_request_tx", {
            "p_job_request_id": job_request_id,
            "p_worker_id": body.worker_id,
            "p_action": body.action
        })
        if tx_data:
            status_code = tx_data.get("result_code", 200)
            if status_code == 409:
                raise HTTPException(status_code=409, detail=tx_data.get("message", "This job is no longer available."))
            elif status_code == 404:
                raise HTTPException(status_code=404, detail=tx_data.get("message", "Job or worker not found."))
            elif status_code == 400:
                raise HTTPException(status_code=400, detail=tx_data.get("message", "Invalid action."))

            if body.action == "accept":
                # Send FCM push to user (ONLY point where phone is revealed)
                _send_fcm_to_user(
                    tx_data["user_id"],
                    "Worker on the way! 🎉",
                    f"{tx_data['worker_name']} accepted your request and is heading over.",
                    {
                        "type": "job_accepted",
                        "job_request_id": str(job_request_id),
                        "worker_name": str(tx_data['worker_name']),
                        "worker_phone": str(tx_data['worker_phone']),
                        "worker_id": str(body.worker_id)
                    }
                )
                return {"status": "success", "message": "Job accepted successfully."}
            elif body.action == "reject":
                await notify_next_worker(job_request_id)
                return {"status": "success", "message": "Job offer rejected."}
    except HTTPException:
        raise
    except Exception as rpc_err:
        logger.debug(f"RPC respond_to_job_request_tx not available ({rpc_err}), falling back to guarded queries.")

    # 1. Fetch job_request
    res = supabase.table("job_requests").select("*").eq("id", job_request_id).maybe_single().execute()
    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Job request not found.")

    job_req = res.data
    status = job_req.get("status")

    # If status is already accepted, cancelled, or rejected_all -> 409 Conflict
    if status in ("accepted", "cancelled", "rejected_all", "expired"):
        # Double submit check: if already accepted by THIS worker, return 200 OK
        if status == "accepted" and str(job_req.get("accepted_worker_id")) == str(body.worker_id):
            return {"status": "success", "message": "Job already accepted by you."}
        raise HTTPException(status_code=409, detail="This job is no longer available.")

    if body.action == "accept":
        # Defensive check: re-verify worker availability
        w_res = supabase.table("workers").select("*").eq("id", body.worker_id).maybe_single().execute()
        if not w_res or not w_res.data:
            raise HTTPException(status_code=404, detail="Worker not found.")
        worker = w_res.data
        if worker.get("is_available") is False:
            raise HTTPException(status_code=409, detail="Worker is currently busy on another job.")

        # Update job_requests -> accepted
        supabase.table("job_requests").update({
            "status": "accepted",
            "accepted_worker_id": body.worker_id,
            "accepted_at": now_str,
            "updated_at": now_str
        }).eq("id", job_request_id).execute()

        # Update job_notification_attempts row -> accepted
        try:
            supabase.table("job_notification_attempts").update({
                "status": "accepted",
                "responded_at": now_str
            }).eq("job_request_id", job_request_id).eq("worker_id", body.worker_id).execute()
        except Exception as e:
            logger.warning(f"Failed to update notification attempt: {e}")

        # Mark worker is_available = false
        supabase.table("workers").update({
            "is_available": False,
            "updated_at": now_str
        }).eq("id", body.worker_id).execute()

        # Fetch user's fcm_token & worker details
        worker_name = worker.get("name") or worker.get("full_name") or "Worker"
        worker_phone = worker.get("phone") or worker.get("phone_number") or ""

        # Push to user: "Worker on the way! 🎉"
        # PRIVACY NOTICE: This is the ONLY place worker phone is sent to the user
        _send_fcm_to_user(
            job_req["user_id"],
            "Worker on the way! 🎉",
            f"{worker_name} accepted your request and is heading over.",
            {
                "type": "job_accepted",
                "job_request_id": str(job_request_id),
                "worker_name": str(worker_name),
                "worker_phone": str(worker_phone),
                "worker_id": str(body.worker_id)
            }
        )

        return {"status": "success", "message": "Job accepted successfully."}

    elif body.action == "reject":
        # Update matching job_notification_attempts row -> rejected
        try:
            supabase.table("job_notification_attempts").update({
                "status": "rejected",
                "responded_at": now_str
            }).eq("job_request_id", job_request_id).eq("worker_id", body.worker_id).execute()
        except Exception as e:
            logger.warning(f"Failed to update notification attempt: {e}")

        # Notify next worker
        await notify_next_worker(job_request_id)

        return {"status": "success", "message": "Job offer rejected."}

    else:
        raise HTTPException(status_code=400, detail="Invalid action.")


@router.post("/{job_request_id}/timeout-check")
async def timeout_check_job_request(job_request_id: str, worker_id: Optional[str] = None):
    """
    3.4 QStash callback ~30s after notify was sent.
    Idempotent check: if status moved past notifying or attempt already responded -> no-op.
    Uses SELECT ... FOR UPDATE row locking in PostgreSQL transaction.
    """
    now_str = datetime.now(timezone.utc).isoformat()

    try:
        tx_data = _safe_rpc_jsonb("timeout_check_job_request_tx", {
            "p_job_request_id": job_request_id,
            "p_worker_id": worker_id
        })
        if tx_data:
            if tx_data.get("status") == "ignored":
                return tx_data
            elif tx_data.get("status") == "timeout_processed":
                await notify_next_worker(job_request_id)
                return {"status": "success", "message": "Timeout processed, moving to next worker."}
    except Exception as rpc_err:
        logger.debug(f"RPC timeout_check_job_request_tx not available ({rpc_err}), falling back to guarded queries.")

    res = supabase.table("job_requests").select("*").eq("id", job_request_id).maybe_single().execute()
    if not res or not res.data:
        return {"status": "ignored", "reason": "Job request not found"}

    job_req = res.data
    status = job_req.get("status")

    if status not in ("pending", "notifying"):
        return {"status": "ignored", "reason": f"Job request in state '{status}'"}

    # Check attempt status if worker_id provided
    if worker_id:
        att_res = supabase.table("job_notification_attempts").select("status").eq("job_request_id", job_request_id).eq("worker_id", worker_id).maybe_single().execute()
        if att_res and att_res.data:
            att_status = att_res.data.get("status")
            if att_status != "sent":
                return {"status": "ignored", "reason": f"Attempt state is '{att_status}'"}

            # Mark attempt as timed_out
            supabase.table("job_notification_attempts").update({
                "status": "timed_out",
                "responded_at": now_str
            }).eq("job_request_id", job_request_id).eq("worker_id", worker_id).execute()

    # Trigger next worker notification
    await notify_next_worker(job_request_id)

    return {"status": "success", "message": "Timeout processed, moving to next worker."}


@router.post("/{job_request_id}/cancel")
async def cancel_job_request(job_request_id: str, body: JobCancelRequest):
    """
    3.5 User-initiated cancel while pending/notifying.
    Set status=cancelled, send silent FCM push to currently-offered worker.
    """
    now_str = datetime.now(timezone.utc).isoformat()

    res = supabase.table("job_requests").select("*").eq("id", job_request_id).maybe_single().execute()
    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Job request not found.")

    job_req = res.data
    if str(job_req.get("user_id")) != str(body.user_id):
        raise HTTPException(status_code=403, detail="Not authorized to cancel this job request.")

    # Set status = cancelled
    supabase.table("job_requests").update({
        "status": "cancelled",
        "updated_at": now_str
    }).eq("id", job_request_id).execute()

    # Find currently notified worker attempt
    att_res = supabase.table("job_notification_attempts").select("worker_id").eq("job_request_id", job_request_id).eq("status", "sent").order("sent_at", desc=True).limit(1).execute()
    if att_res and att_res.data:
        curr_worker_id = att_res.data[0].get("worker_id")
        if curr_worker_id:
            w_res = supabase.table("workers").select("fcm_token").eq("id", curr_worker_id).maybe_single().execute()
            if w_res and w_res.data:
                token = w_res.data.get("fcm_token")
                if token:
                    _send_silent_fcm(token, {"type": "job_offer_withdrawn", "job_request_id": str(job_request_id)})

    return {"status": "success", "message": "Job request cancelled successfully."}


@router.get("/request/{job_request_id}")
async def get_job_request_status(job_request_id: str):
    """
    5.2 User polling endpoint for live status safety net.
    Worker phone is ONLY returned if status == 'accepted'.
    """
    res = supabase.table("job_requests").select("*").eq("id", job_request_id).maybe_single().execute()
    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Job request not found.")

    job_req = res.data
    status = job_req.get("status")

    response_data = {
        "job_request_id": job_req["id"],
        "status": status,
        "service_type": job_req.get("service_type"),
        "created_at": job_req.get("created_at"),
        "accepted_worker_id": job_req.get("accepted_worker_id"),
    }

    # Worker details exposed ONLY after acceptance
    if status == "accepted" and job_req.get("accepted_worker_id"):
        w_res = supabase.table("workers").select("name, phone, rating").eq("id", job_req["accepted_worker_id"]).maybe_single().execute()
        if w_res and w_res.data:
            w_data = w_res.data
            response_data["worker_name"] = w_data.get("name") or "Worker"
            response_data["worker_phone"] = w_data.get("phone") or ""
            response_data["worker_rating"] = w_data.get("rating")

    return response_data



