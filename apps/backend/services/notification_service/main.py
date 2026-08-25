# services/notification_service/main.py
import shared.firebase_init  # noqa: F401 — must be first
"""
Notification Service — Multi-channel (FCM + Email)
MIGRATED: Firestore → Supabase. gcp_exc.AlreadyExists → ON CONFLICT DO NOTHING
MIGRATED: Pub/Sub push → Direct HTTP from outbox dispatcher
KEPT: Firebase messaging (FCM) — completely unchanged
KEPT: Email service — completely unchanged
"""
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_internal_secret
from shared.database import supabase
from shared.logging import log
from firebase_admin import messaging
from services.notification_service.email_service import send_email
from services.notification_service.email_templates import TEMPLATES
import json
import os
import traceback
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("notification_service")

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
EMAIL_ENABLED = os.getenv("EMAIL_ENABLED", "true").lower() == "true"


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


@app.get("/health")
def health():
    return {"status": "ok", "service": "notification_service", "email_enabled": EMAIL_ENABLED}


# ─── Internal notify endpoint (outbox dispatcher calls this) ──

@app.post("/internal/notify")
def internal_notify(request: Request):
    """
    BEFORE: Pub/Sub push subscription trigger
    AFTER: Direct HTTP from outbox dispatcher

    Idempotency: ON CONFLICT DO NOTHING on idempotency_key (replaces gcp_exc.AlreadyExists)
    """
    try:
        verify_internal_secret(request)
        raw = request.state.raw_body
        data = json.loads(raw)

        event_type = data.get("event_type", "")
        job_id = data.get("job_id")
        payload = data.get("payload", {})
        idempotency_key = f"{event_type}_{job_id}"

        # Idempotency check via UNIQUE constraint
        # ON CONFLICT DO NOTHING replaces gcp_exc.AlreadyExists
        try:
            supabase.table("notifications").insert({
                "user_id": payload.get("employer_id") or payload.get("user_id") or payload.get("worker_id") or "system",
                "job_id": job_id,
                "type": event_type,
                "title": event_type,
                "body": json.dumps(payload),
                "data": payload,
                "idempotency_key": idempotency_key,
                "sent": False,
            }).execute()
        except Exception as e:
            if "duplicate" in str(e).lower() or "23505" in str(e):
                log("notification_service", "internal_notify", "duplicate_skip",
                    idempotency_key=idempotency_key)
                return {"status": "already_processed"}
            raise

        # Route event to FCM + Email
        try:
            _route_event(event_type, job_id, payload)
            # Mark as sent
            supabase.table("notifications").update({"sent": True}).eq(
                "idempotency_key", idempotency_key
            ).execute()
            log("notification_service", "internal_notify", "sent",
                event_type=event_type, job_id=job_id)
        except Exception as e:
            log("notification_service", "internal_notify", "send_failed",
                event_type=event_type, error=str(e), severity="ERROR")

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        log("notification_service", "internal_notify", "unexpected_error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal server error")


# ─── Event Router ───────────────────────────────────────────

def _route_event(event_type: str, job_id: str, payload: dict):
    """Route outbox event to FCM + Email channels."""

    if event_type == "JOB_ASSIGNED":
        job = supabase.table("jobs").select("*, employer:employer_id(*)").eq("id", job_id).single().execute().data or {}
        employer = job.get("employer", {})
        worker_result = supabase.table("users").select("*").eq("id", job.get("worker_id")).single().execute()
        worker = worker_result.data or {}

        # FCM already sent directly by job_service.accept_job() with type WORKER_ASSIGNED.
        # Only send email here to avoid duplicate push notification to customer.
        _send_event_email("job_accepted", "customer", employer.get("email"), {
            "customerName": employer.get("name", "Customer"),
            "workerName": worker.get("name", "Worker"),
            "jobId": job_id,
        })

    elif event_type == "JOB_ACK":
        job = supabase.table("jobs").select("*, employer:employer_id(*)").eq("id", job_id).single().execute().data or {}
        employer = job.get("employer", {})
        worker_result = supabase.table("users").select("name").eq("id", job.get("worker_id")).single().execute()
        worker = worker_result.data or {}

        _send_fcm(
            employer.get("fcm_token"), "Worker arrived", "At your location",
            {"type": "worker_arrived", "job_id": job_id},
        )
        _send_event_email("job_ack", "customer", employer.get("email"), {
            "customerName": employer.get("name", "Customer"),
            "workerName": worker.get("name", "Worker"),
            "jobId": job_id,
        })

    elif event_type == "JOB_COMPLETED":
        job = supabase.table("jobs").select("*, employer:employer_id(*)").eq("id", job_id).single().execute().data or {}
        employer = job.get("employer", {})
        worker_result = supabase.table("users").select("*").eq("id", job.get("worker_id")).single().execute()
        worker = worker_result.data or {}

        _send_fcm(
            employer.get("fcm_token"), "Job done — time to pay", "Tap to pay",
            {"type": "job_completed", "job_id": job_id},
        )
        _send_event_email("job_completed", "customer", employer.get("email"), {
            "customerName": employer.get("name", "Customer"),
            "workerName": worker.get("name", "Worker"),
            "jobId": job_id,
            "amount": job.get("amount", 0),
        })

    elif event_type == "JOB_CANCELLED":
        job = supabase.table("jobs").select("*, employer:employer_id(*)").eq("id", job_id).single().execute().data or {}
        employer = job.get("employer", {})
        _send_fcm(
            employer.get("fcm_token"), "Job cancelled", "Finding another worker...",
            {"type": "job_cancelled", "job_id": job_id},
        )

    elif event_type == "PAYMENT_CAPTURED":
        job = supabase.table("jobs").select("*, employer:employer_id(*)").eq("id", job_id).single().execute().data or {}
        employer = job.get("employer", {})
        worker_result = supabase.table("users").select("*").eq("id", job.get("worker_id")).single().execute()
        worker = worker_result.data or {}

        _send_event_email("payment_success", "customer", employer.get("email"), {
            "customerName": employer.get("name", "Customer"),
            "workerName": worker.get("name", "Worker"),
            "jobId": job_id,
            "amount": job.get("amount", 0),
        })
        _send_event_email("payment_success", "worker", worker.get("email"), {
            "workerName": worker.get("name", "Worker"),
            "jobId": job_id,
            "amount": job.get("amount", 0),
        })

    else:
        log("notification_service", "_route_event", "unknown_type",
            event_type=event_type, severity="WARNING")


# ─── Email helpers ──────────────────────────────────────────

def _send_event_email(event: str, recipient_type: str, email: str | None, data: dict):
    """Look up template and send email."""
    if not EMAIL_ENABLED or not email:
        return
    templates = TEMPLATES.get(event)
    if not templates or recipient_type not in templates:
        return
    try:
        subject, html_body = templates[recipient_type](data)
        send_email(email, subject, html_body)
    except Exception as e:
        logger.error(f"Email send error [{event}→{email}]: {e}")


# ─── FCM Push (KEPT UNCHANGED) ─────────────────────────────

def _send_fcm(token: str | None, title: str, body: str, data: dict):
    if not token:
        log("notification_service", "_send_fcm", "no_token", title=title)
        return
    try:
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            token=token,
            android=messaging.AndroidConfig(priority="high"),
        )
        resp = messaging.send(msg)
        log("notification_service", "_send_fcm", "sent", message_id=resp)
    except Exception as e:
        log("notification_service", "_send_fcm", "failed",
            error=str(e), severity="WARNING")
