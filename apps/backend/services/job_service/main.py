# services/job_service/main.py
import shared.firebase_init  # noqa: F401 — must be first
"""
Job Service — Manages job lifecycle after creation.
  • POST /v1/jobs/{id}/accept   — Worker accepts (Redis lock + Supabase RPC)
  • POST /v1/jobs/{id}/reject   — Worker rejects (Redis state + cascade logic)
  • POST /v1/jobs/{id}/ack      — Worker confirms arrival
  • POST /v1/jobs/{id}/complete — User or worker confirms completion
  • POST /internal/job/timeout  — QStash callback when ack timer expires
  • POST /internal/jobs/{id}/dispatch-timeout — Dispatch timeout
  • POST /v1/jobs/{id}/review   — Submit review

MIGRATED: Firestore → Supabase PostgreSQL
KEPT: Firebase Auth, FCM, QStash, Redis — all unchanged
"""
from fastapi import FastAPI, Request, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from shared.auth import verify_firebase_token, verify_qstash_signature
from shared.database import supabase
from shared.models import AcceptJobRequest, CompleteJobRequest, RejectJobRequest
from shared.qstash import enqueue_task
from shared.logging import log
from shared import redis_client
from firebase_admin import messaging
from datetime import datetime, timezone, timedelta
import uuid
import os
import json
import traceback

app = FastAPI(title="Job Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

JOB_TIMEOUT_SECONDS = int(os.getenv("JOB_TIMEOUT_SECONDS", "120"))
JOB_SERVICE_TIMEOUT_URL = os.getenv("JOB_SERVICE_TIMEOUT_URL", "")
DISPATCH_TIMEOUT_SECONDS = int(os.getenv("DISPATCH_TIMEOUT_SECONDS", "300"))


@app.get("/health")
def health():
    return {"status": "ok", "service": "job_service"}


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


# ─── Helper: Send FCM (KEPT UNCHANGED) ──────────────────────

def _send_fcm_to_user(user_id: str, title: str, body: str, data: dict):
    """Send FCM notification to a user by looking up their FCM token."""
    try:
        result = supabase.table("users").select("fcm_token").eq("id", user_id).single().execute()
        if not result.data:
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
        log("job_service", "_send_fcm_to_user", "sent",
            user_id=user_id, title=title)
    except Exception as e:
        log("job_service", "_send_fcm_to_user", "error",
            severity="WARNING", user_id=user_id, error=str(e))


def _send_silent_fcm(token: str, data: dict):
    """Send data-only (silent) FCM message."""
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
        log("job_service", "_send_silent_fcm", "error",
            severity="WARNING", error=str(e))


# ─── Accept Job (Redis Lock + Supabase Atomic) ──────────────

@app.post("/v1/jobs/{job_id}/accept")
def accept_job(
    job_id: str,
    body: AcceptJobRequest,
    uid: str = Depends(verify_firebase_token),
):
    """
    Worker accepts a job.
    1. Redis NX lock prevents simultaneous accepts.
    2. Supabase RPC ensures exactly ONE winner (atomic update).
    3. FCM sent to customer + other workers.
    """
    # Step 1: Attempt Redis distributed lock
    lock_key = f"lock:job:{job_id}"
    acquired = redis_client.acquire_lock(lock_key, body.worker_id, ex=10)
    if not acquired:
        raise HTTPException(status_code=409, detail="Job already accepted")

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(seconds=JOB_TIMEOUT_SECONDS)

    try:
        # Get current job
        job_result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
        if not job_result.data:
            raise HTTPException(404, "Job not found")

        job = job_result.data

        if job.get("status") not in ("open", "matched"):
            raise HTTPException(409, f"Job is no longer available (status: {job.get('status')})")

        # Look up worker's internal UUID
        worker_user = supabase.table("users").select("id, name, phone, fcm_token").eq("firebase_uid", body.worker_id).single().execute()
        worker_info = worker_user.data or {}
        worker_uuid = worker_info.get("id")

        # Atomic update: assign worker, mark worker busy, and emit outbox event.
        accept_result = supabase.rpc("accept_job_atomic", {
            "p_job_id": job_id,
            "p_worker_id": str(worker_uuid),
        }).execute()
        if accept_result.data is False:
            raise HTTPException(status_code=409, detail="Job already accepted")

        # Step 3: Send FCM to customer — "Worker Found!"
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

        # Step 4: Notify other workers that this job is taken
        # Uses count_by_pattern to find all workers who were notified about this job
        try:
            notified = redis_client.count_by_pattern(f"job_notified:{job_id}:*")
            for redis_key in notified:
                # Extract worker_id from key "job_notified:{job_id}:{worker_id}"
                other_worker_id = redis_key.split(":")[-1]
                if other_worker_id == str(worker_uuid):
                    continue  # Skip the worker who just accepted
                # Look up FCM token for the other worker
                try:
                    other_user = supabase.table("users").select("fcm_token").eq("id", other_worker_id).single().execute()
                    other_token = (other_user.data or {}).get("fcm_token", "")
                    if other_token:
                        _send_silent_fcm(other_token, {
                            "type": "JOB_TAKEN",
                            "job_id": job_id,
                            "message": "Another worker accepted this job",
                        })
                except Exception:
                    pass  # Best-effort — don't block the accept flow
                # Clean up Redis notification state
                redis_client.release_lock(redis_key)
        except Exception as e:
            log("job_service", "accept_job", "notify_others_error",
                severity="WARNING", job_id=job_id, error=str(e))

        # Step 5: Enqueue ack timeout task via QStash (KEPT UNCHANGED)
        try:
            if JOB_SERVICE_TIMEOUT_URL:
                enqueue_task(
                    url=JOB_SERVICE_TIMEOUT_URL,
                    body={
                        "job_id": job_id,
                    },
                    delay_seconds=JOB_TIMEOUT_SECONDS + 5,
                )
        except Exception as e:
            log("job_service", "accept_job", "timeout_enqueue_failed",
                severity="WARNING", job_id=job_id, error=str(e))

        log("job_service", "accept_job", "accepted",
            job_id=job_id, worker_id=body.worker_id)

        return {
            "status": "ok",
            "job_id": job_id,
            "message": "Job accepted. Arrive within 2 minutes.",
        }

    except HTTPException:
        raise
    except Exception as e:
        log("job_service", "accept_job", "error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal server error")
    finally:
        redis_client.release_lock(lock_key)


# ─── Reject Job (Worker declines) ───────────────────────────

@app.post("/v1/jobs/{job_id}/reject")
def reject_job(
    job_id: str,
    body: RejectJobRequest,
    uid: str = Depends(verify_firebase_token),
):
    """Worker rejects/declines a job offer. Redis cascade logic."""
    redis_key = f"job_notified:{job_id}:{body.worker_id}"
    redis_client.set_state(redis_key, "rejected", ex=300)

    # Get job
    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data

    log("job_service", "reject_job", "rejected",
        job_id=job_id, worker_id=body.worker_id, reason=body.reason)

    return {"status": "rejected", "job_id": job_id}


# ─── Worker Acknowledge ─────────────────────────────────────

@app.post("/v1/jobs/{job_id}/ack")
def ack_job(job_id: str, uid: str = Depends(verify_firebase_token)):
    """Worker confirms arrival."""
    # Look up worker UUID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    worker_uuid = user_result.data["id"]

    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
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

    # Outbox event
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": "JOB_ACK",
        "payload": {"worker_id": str(worker_uuid)},
    }).execute()

    log("job_service", "ack_job", "acknowledged",
        job_id=job_id, worker_id=uid)

    return {"status": "ok", "job_id": job_id}


# ─── Complete Job (dual confirmation) ───────────────────────

@app.post("/v1/jobs/{job_id}/complete")
def complete_job(
    job_id: str,
    body: CompleteJobRequest,
    uid: str = Depends(verify_firebase_token),
):
    """Either user or worker confirms job completion."""
    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
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

    # Release worker + increment job count
    worker_id = job.get("worker_id")
    if worker_id:
        supabase.table("workers").update({
            "is_available": True,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", worker_id).execute()
        # Atomically increment total_jobs counter
        try:
            supabase.rpc("increment_worker_total_jobs", {"p_worker_id": worker_id}).execute()
        except Exception as e:
            log("job_service", "complete_job", "increment_error",
                severity="WARNING", worker_id=str(worker_id), error=str(e))

    # Notify customer — "Job Completed!"
    employer_id = job.get("employer_id")
    if employer_id:
        _send_fcm_to_user(
            employer_id,
            title="Job Completed! ✅",
            body="Your job has been marked as completed.",
            data={"type": "JOB_COMPLETED", "job_id": job_id},
        )

    # Outbox event
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": "JOB_COMPLETED",
        "payload": {
            "employer_id": job.get("employer_id"),
            "worker_id": str(worker_id),
        },
    }).execute()

    log("job_service", "complete_job", "completed", job_id=job_id)

    return {"status": "completed", "job_id": job_id}


# ─── Timeout Handler (QStash callback — KEPT UNCHANGED) ─────

@app.post("/internal/job/timeout")
def handle_timeout(request: Request):
    """QStash fires this when the ack timer expires."""
    try:
        raw = request.state.raw_body
        verify_qstash_signature(request, raw)
        payload = json.loads(raw)
    except HTTPException:
        raise
    except Exception as e:
        log("job_service", "timeout", "parse_error",
            severity="ERROR", error=str(e))
        raise HTTPException(400, "Invalid request")

    job_id = payload.get("job_id")
    if not job_id:
        return {"status": "skipped", "reason": "missing job_id"}

    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        return {"status": "not_found"}

    job = result.data

    if job.get("status") != "accepted":
        return {"status": "already_handled"}

    # Revert to open for re-matching
    supabase.table("jobs").update({
        "status": "open",
        "worker_id": None,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    # Release worker
    if job.get("worker_id"):
        supabase.table("workers").update({
            "is_available": True,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", job["worker_id"]).execute()

    # Outbox event for re-matching
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": "JOB_TIMEOUT",
        "payload": {"timed_out_worker": str(job.get("worker_id"))},
    }).execute()

    log("job_service", "timeout", "timed_out", job_id=job_id)

    return {"status": "timed_out", "job_id": job_id}


# ─── Dispatch Timeout ───────────────────────────────────────

@app.post("/internal/jobs/{job_id}/dispatch-timeout")
def handle_dispatch_timeout(request: Request, job_id: str):
    """QStash fires this when the dispatch window expires (300s)."""
    try:
        raw = request.state.raw_body
        verify_qstash_signature(request, raw)
    except HTTPException:
        raise

    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        return {"status": "not_found"}

    job = result.data

    if job.get("status") not in ("open", "matched"):
        return {"status": "already_handled"}

    supabase.table("jobs").update({
        "status": "cancelled",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    # Notify customer via FCM
    employer_id = job.get("employer_id")
    if employer_id:
        _send_fcm_to_user(
            employer_id,
            title="No Workers Found",
            body="No workers available nearby. Try again or increase budget.",
            data={"type": "JOB_TIMEOUT", "job_id": job_id},
        )

    log("job_service", "dispatch_timeout", "no_workers_found", job_id=job_id)

    return {"status": "no_workers_found", "job_id": job_id}


# ─── Review Job ──────────────────────────────────────────────

class JobReviewRequest(BaseModel):
    rating: float
    comment: str | None = None

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v):
        if not (1.0 <= v <= 5.0):
            raise ValueError("Rating must be between 1.0 and 5.0")
        return v


@app.post("/v1/jobs/{job_id}/review")
def review_job(
    job_id: str,
    body: JobReviewRequest,
    uid: str = Depends(verify_firebase_token),
):
    """Submit a review for a completed job. Uses Supabase RPC for atomic operation."""
    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    worker_id = job.get("worker_id")
    if not worker_id:
        raise HTTPException(400, "No worker assigned to this job")

    # Look up reviewer UUID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    reviewer_id = user_result.data["id"]

    if job.get("employer_id") != reviewer_id:
        raise HTTPException(403, "Only the customer who created this job can review it")

    # Atomic review + rating update via RPC
    supabase.rpc("submit_review_atomic", {
        "p_job_id": job_id,
        "p_reviewer_id": str(reviewer_id),
        "p_reviewee_id": str(worker_id),
        "p_rating": int(body.rating),
        "p_comment": body.comment,
    }).execute()

    log("job_service", "review_job", "success",
        job_id=job_id, worker_id=str(worker_id), rating=body.rating)
    return {"status": "success", "message": "Review submitted and worker rating updated"}
