# services/request_service/main.py
import shared.firebase_init  # noqa: F401 — must be first
"""
Request Service — Creates new jobs.
POST /v1/jobs → validate input → write job + outbox event.

MIGRATED: Firestore → Supabase PostgreSQL
KEPT: Firebase Auth (verify_firebase_token)
"""
from fastapi import FastAPI, Depends, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared.models import CreateJobRequest, VALID_SKILLS
from shared.geo import haversine_km, PILOT_CENTER_LAT, PILOT_CENTER_LNG, PILOT_RADIUS_KM
from shared.logging import log
from datetime import datetime, timezone, timedelta
import uuid
import os
import httpx

app = FastAPI(title="Request Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    """Transform raw Pydantic validation errors into clean, user-friendly messages."""
    errors = exc.errors()
    messages = []
    field_labels = {
        "description": "Issue description",
        "service_type": "Service type",
        "location": "Location",
        "skill": "Service type",
        "lat": "Latitude",
        "lng": "Longitude",
        "urgency": "Urgency",
        "budget": "Budget",
        "scheduled_at": "Scheduled time",
    }
    for error in errors:
        field = error.get("loc", [])[-1] if error.get("loc") else "field"
        msg = error.get("msg", "Invalid input")
        label = field_labels.get(str(field), str(field).replace("_", " ").title())
        # Make common Pydantic messages more user-friendly
        friendly_msg = (
            msg.replace("String should have at least", "Please enter at least")
               .replace("Field required", "This field is required")
               .replace("Input should be", "Please provide a valid value —")
        )
        messages.append(f"{label}: {friendly_msg}")
    return JSONResponse(
        status_code=422,
        content={
            "detail": messages[0] if len(messages) == 1 else messages,
            "success": False,
        },
    )

JOB_TIMEOUT_SECONDS = int(os.getenv("JOB_TIMEOUT_SECONDS", "120"))


_FALLBACK_SERVICES = [
    {"id": "electrician", "title": "Electrician", "category": "Home", "icon": "electrical_services_rounded", "image_url": "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400", "price_min": 150, "price_max": 350, "rating": 4.8, "sort_order": 1, "is_active": True},
    {"id": "plumber", "title": "Plumber", "category": "Home", "icon": "plumbing_rounded", "image_url": "https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400", "price_min": 150, "price_max": 350, "rating": 4.7, "sort_order": 2, "is_active": True},
    {"id": "laptop_repair", "title": "Laptop repair", "category": "Tech", "icon": "laptop_mac_rounded", "image_url": "https://images.unsplash.com/photo-1588702547954-4800f964702a?w=400", "price_min": 200, "price_max": 500, "rating": 4.9, "sort_order": 3, "is_active": True},
    {"id": "phone_repair", "title": "Phone repair", "category": "Tech", "icon": "phone_android_rounded", "image_url": "https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400", "price_min": 150, "price_max": 400, "rating": 4.8, "sort_order": 4, "is_active": True},
    {"id": "carpenter", "title": "Carpenter", "category": "Home", "icon": "carpenter_rounded", "image_url": "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400", "price_min": 180, "price_max": 400, "rating": 4.6, "sort_order": 5, "is_active": True},
    {"id": "painter", "title": "Painter", "category": "Home", "icon": "format_paint_rounded", "image_url": "https://images.unsplash.com/photo-1562259949-e8e7689d7828?w=400", "price_min": 250, "price_max": 600, "rating": 4.8, "sort_order": 6, "is_active": True},
    {"id": "ac_service", "title": "AC service", "category": "Home", "icon": "ac_unit_rounded", "image_url": "https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400", "price_min": 200, "price_max": 500, "rating": 4.7, "sort_order": 7, "is_active": True},
    {"id": "cleaning", "title": "Cleaning", "category": "Home", "icon": "cleaning_services_rounded", "image_url": "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400", "price_min": 150, "price_max": 350, "rating": 4.8, "sort_order": 8, "is_active": True},
    {"id": "car_wash", "title": "Car Wash", "category": "Vehicle", "icon": "local_car_wash_rounded", "image_url": "https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=400", "price_min": 200, "price_max": 400, "rating": 4.7, "sort_order": 9, "is_active": True},
    {"id": "bike_mechanic", "title": "Bike mechanic", "category": "Vehicle", "icon": "two_wheeler_rounded", "image_url": "https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=400", "price_min": 150, "price_max": 350, "rating": 4.6, "sort_order": 10, "is_active": True},
    {"id": "hair_salon", "title": "Hair Salon", "category": "Beauty", "icon": "content_cut_rounded", "image_url": "https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400", "price_min": 150, "price_max": 300, "rating": 4.8, "sort_order": 11, "is_active": True},
    {"id": "spa_massage", "title": "Spa & Massage", "category": "Beauty", "icon": "spa_rounded", "image_url": "https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 12, "is_active": True},
]


@app.get("/v1/services")
def list_services():
    """Return all active services from the database, with fallback if table doesn't exist."""
    try:
        result = (
            supabase.table("services")
            .select("*")
            .eq("is_active", True)
            .order("sort_order")
            .execute()
        )
        return {"services": result.data or _FALLBACK_SERVICES}
    except Exception as e:
        # If the services table doesn't exist yet (PGRST205), return fallback catalog
        error_str = str(e)
        if "PGRST205" in error_str or "Could not find the table" in error_str:
            log("request_service", "list_services", "fallback",
                reason="services table not found, returning fallback catalog")
            return {"services": _FALLBACK_SERVICES}
        raise


@app.get("/health")
def health():
    return {"status": "ok", "service": "request_service"}


@app.post("/v1/jobs")
def create_job(body: CreateJobRequest, uid: str = Depends(verify_firebase_token)):
    """
    Create a new job request.
    1. Auth (handled by Depends)
    2. Validate (handled by Pydantic model)
    3. Geo-fence check
    4. Insert into jobs table
    5. Insert outbox event (pg_net trigger handles downstream delivery)
    6. Return job_id
    """
    # Geo-fence check: reject requests outside pilot zone
    distance = haversine_km(
        body.lat, body.lng,
        PILOT_CENTER_LAT, PILOT_CENTER_LNG,
    )
    if distance > PILOT_RADIUS_KM:
        raise HTTPException(
            400,
            f"Location is {distance:.1f}km from Mysuru center. "
            f"Service available within {PILOT_RADIUS_KM}km radius only.",
        )

    job_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    # Determine status based on urgency
    if body.urgency == "scheduled":
        status = "open"  # mapped from old 'scheduled'
        expires_at = None
    else:
        status = "open"  # mapped from old 'searching'
        expires_at = (now + timedelta(minutes=10)).isoformat()

    # Look up employer's internal UUID from firebase_uid
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    employer_id = user_result.data["id"]

    # Insert job
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

    # Insert outbox event — pg_net trigger handles delivery to matching/notification
    event_type = "JOB_SCHEDULED" if body.urgency == "scheduled" else "JOB_CREATED"
    matching_payload = {
        "user_id": uid,
        "employer_id": employer_id,
        "skill": body.skill,
        "lat": body.lat,
        "lng": body.lng,
        "urgency": body.urgency,
        "budget": body.budget,
        "description": body.description,
        "radius_km": 5,
        "scheduled_at": body.scheduled_at.isoformat() if body.scheduled_at else None,
    }
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": event_type,
        "payload": matching_payload,
    }).execute()

    # If scheduled, also write to scheduled_jobs
    if body.urgency == "scheduled":
        supabase.table("scheduled_jobs").insert({
            "job_id": job_id,
            "scheduled_at": body.scheduled_at.isoformat(),
        }).execute()

    # ── Direct call to matching service (bypasses broken pg_net trigger) ──
    # The outbox_event_trigger relies on pg_net + app.ops_service_url database
    # setting which may not be configured. This direct call ensures matching
    # happens reliably even when the Postgres trigger is non-functional.
    if event_type == "JOB_CREATED":
        matching_url = os.getenv("MATCHING_SERVICE_URL", "")
        if matching_url:
            if not matching_url.startswith(("http://", "https://")):
                matching_url = f"http://{matching_url}"
            try:
                log("request_service", "create_job", "calling_matching",
                    job_id=job_id, matching_url=matching_url)
                resp = httpx.post(
                    f"{matching_url}/internal/match",
                    json={
                        "job_id": job_id,
                        "payload": matching_payload,
                    },
                    headers={
                        "Content-Type": "application/json",
                        "X-Internal-Secret": os.getenv("INTERNAL_SECRET", ""),
                    },
                    timeout=15.0,
                )
                log("request_service", "create_job", "matching_response",
                    job_id=job_id, status=resp.status_code)
            except Exception as e:
                log("request_service", "create_job", "matching_call_failed",
                    severity="WARNING", job_id=job_id, error=str(e))
        else:
            log("request_service", "create_job", "no_matching_url",
                severity="WARNING", job_id=job_id)

    log("request_service", "create_job", "created",
        job_id=job_id, skill=body.skill, urgency=body.urgency, uid=uid)

    return {
        "status": "ok",
        "job_id": job_id,
        "message": "Job created successfully",
    }


@app.get("/v1/jobs")
def list_jobs(uid: str = Depends(verify_firebase_token)):
    """List all jobs for the authenticated customer, most recent first."""
    result = (supabase.table("jobs")
        .select("*")
        .eq("employer_id", uid)
        .order("created_at", desc=True)
        .limit(50)
        .execute())
    return {"jobs": result.data or []}


@app.get("/v1/jobs/{job_id}")
def get_job(job_id: str, uid: str = Depends(verify_firebase_token)):
    """Get details of a job request. Only the employer or assigned worker can view."""
    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    # Allow employer or assigned worker to view
    if job.get("employer_id") != uid and job.get("worker_id") != uid:
        raise HTTPException(403, "Not authorized to view this job")

    return job


@app.post("/v1/jobs/{job_id}/cancel")
def cancel_job(job_id: str, uid: str = Depends(verify_firebase_token)):
    """User cancels a job."""
    CANCELLABLE = {"open", "matched"}

    # Look up employer's internal UUID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    employer_id = user_result.data["id"]

    # Get job
    result = supabase.table("jobs").select("*").eq("id", job_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Job not found")

    job = result.data
    if job.get("employer_id") != employer_id:
        raise HTTPException(403, "Not authorized to cancel this job")
    if job.get("status") not in CANCELLABLE:
        raise HTTPException(
            400,
            f"Cannot cancel job in status '{job.get('status')}'. "
            f"Allowed: {CANCELLABLE}",
        )

    # Update job status
    supabase.table("jobs").update({
        "status": "cancelled",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", job_id).execute()

    # Outbox event
    supabase.table("outbox_events").insert({
        "job_id": job_id,
        "event_type": "JOB_CANCELLED",
        "payload": {"cancelled_by": "user", "employer_id": employer_id},
    }).execute()

    log("request_service", "cancel_job", "cancelled",
        job_id=job_id, uid=uid)

    return {"status": "ok", "message": "Job cancelled"}
 
 
@app.delete("/v1/jobs/{job_id}")
def cancel_job_delete(job_id: str, uid: str = Depends(verify_firebase_token)):
    """User cancels a job using DELETE method."""
    return cancel_job(job_id, uid)
