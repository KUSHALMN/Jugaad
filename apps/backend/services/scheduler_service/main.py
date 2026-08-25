# services/scheduler_service/main.py
import shared.firebase_init  # noqa: F401 — must be first
"""
Scheduler Service — Handles scheduled (future) jobs.

MIGRATED: Firestore → Supabase
MIGRATED: Pub/Sub push → Internal HTTP from outbox dispatcher
KEPT: QStash (enqueue_task, verify_qstash_signature) — completely unchanged
"""
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_qstash_signature, verify_internal_secret
from shared.database import supabase
from shared.qstash import enqueue_task
from shared.logging import log
from datetime import datetime, timezone, timedelta
import json
import uuid
import os
import traceback

app = FastAPI(title="Scheduler Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

SCHEDULER_ACTIVATE_URL = os.getenv("SCHEDULER_ACTIVATE_URL", "")
ADVANCE_HOURS = 2


@app.get("/health")
def health():
    return {"status": "ok", "service": "scheduler_service"}


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


# ─── Outbox dispatcher calls this for JOB_SCHEDULED events ──

@app.post("/internal/schedule")
def handle_scheduled_event(request: Request):
    """
    BEFORE: Pub/Sub push subscription
    AFTER: Direct HTTP from outbox dispatcher

    Enqueues a QStash task to activate the job 2 hours before the slot.
    """
    try:
        verify_internal_secret(request)
        raw = request.state.raw_body
        data = json.loads(raw)

        event_type = data.get("event_type")
        if event_type != "JOB_SCHEDULED":
            return {"status": "skipped", "reason": f"not JOB_SCHEDULED: {event_type}"}

        job_id = data.get("job_id")
        payload = data.get("payload", {})
        scheduled_at_str = payload.get("scheduled_at")

        if not job_id or not scheduled_at_str:
            return {"status": "skipped", "reason": "missing job_id or scheduled_at"}

        # Calculate delay: activate 2 hours before the scheduled slot
        scheduled_at = datetime.fromisoformat(scheduled_at_str)
        if scheduled_at.tzinfo is None:
            scheduled_at = scheduled_at.replace(tzinfo=timezone.utc)

        activate_at = scheduled_at - timedelta(hours=ADVANCE_HOURS)
        now = datetime.now(timezone.utc)
        delay_seconds = max(int((activate_at - now).total_seconds()), 10)

        # Enqueue the activation callback via QStash (KEPT UNCHANGED)
        if SCHEDULER_ACTIVATE_URL:
            msg_id = enqueue_task(
                url=SCHEDULER_ACTIVATE_URL,
                body={"job_id": job_id, "scheduled_at": scheduled_at_str},
                delay_seconds=delay_seconds,
            )
            log("scheduler_service", "schedule_activation", "enqueued",
                job_id=job_id, delay_seconds=delay_seconds, msg_id=msg_id)

        return {"status": "ok", "job_id": job_id}

    except HTTPException:
        raise
    except Exception as e:
        log("scheduler_service", "handle_scheduled_event", "error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal server error")


# ─── QStash callback: activate the scheduled job (KEPT UNCHANGED) ──

@app.post("/internal/scheduler/activate-scheduled")
def activate_scheduled_job(request: Request):
    """QStash fires this 2 hours before the scheduled slot."""
    try:
        raw = request.state.raw_body
        verify_qstash_signature(request, raw)
        payload = json.loads(raw)
    except HTTPException:
        raise

    job_id = payload.get("job_id")
    if not job_id:
        return {"status": "skipped", "reason": "missing job_id"}

    # Check scheduled_jobs
    sched_result = supabase.table("scheduled_jobs").select("*").eq("job_id", job_id).single().execute()
    if not sched_result.data:
        return {"status": "skipped", "reason": "scheduled_job not found"}

    if sched_result.data.get("executed"):
        return {"status": "skipped", "reason": "already_executed"}

    # Read the job
    job_result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not job_result.data:
        return {"status": "error", "reason": "job document missing"}

    job = job_result.data

    if job.get("status") != "open":
        return {"status": "skipped", "reason": f"wrong_status:{job.get('status')}"}

    # Activate: update job to open for matching
    supabase.table("jobs").update({
        "status": "open",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    # Mark scheduled_job as executed
    supabase.table("scheduled_jobs").update({
        "executed": True,
    }).eq("job_id", job_id).execute()

    # Outbox event to trigger matching
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": "JOB_CREATED",
        "payload": {
            "employer_id": job.get("employer_id"),
            "skill": job.get("skill_required"),
            "activated_from_scheduled": True,
        },
    }).execute()

    log("scheduler_service", "activate", "activated", job_id=job_id)

    return {"status": "activated", "job_id": job_id}


# ─── Admin: check upcoming scheduled jobs ────────────────────

@app.get("/internal/scheduler/upcoming")
def get_upcoming_jobs():
    """Returns scheduled jobs in the next 4 hours that haven't been executed."""
    now = datetime.now(timezone.utc)
    cutoff = (now + timedelta(hours=4)).isoformat()

    result = supabase.table("scheduled_jobs").select("*").eq("executed", False).lte("scheduled_at", cutoff).order("scheduled_at").execute()

    return {"status": "ok", "count": len(result.data or []), "jobs": result.data or []}
