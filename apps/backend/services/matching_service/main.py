# services/matching_service/main.py
import shared.firebase_init  # noqa: F401 — must be first
"""
Matching Service — Worker discovery + FCM notification blast.

MIGRATED: Firestore geohash → PostGIS ST_DWithin via Supabase RPC
MIGRATED: Pub/Sub push trigger → Direct HTTP from outbox dispatcher
KEPT: Firebase messaging (FCM) for worker notifications — unchanged
KEPT: Redis state management (Upstash) — unchanged
"""
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from shared.database import supabase
from shared.auth import verify_internal_secret
from shared.logging import log
from shared import redis_client
from firebase_admin import messaging
import json
import os
import traceback
from datetime import datetime, timezone

app = FastAPI(title="Matching Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Max workers to notify per round
MAX_NOTIFY = 5
# Notification state TTL — must match JOB_TIMEOUT_SECONDS so worker countdown
# aligns with server-side expiry (default 120s, not the old 300s)
NOTIFY_TTL = int(os.getenv("JOB_TIMEOUT_SECONDS", "120"))


@app.get("/health")
def health():
    return {"status": "ok", "service": "matching_service"}


@app.middleware("http")
async def capture_raw_body(request: Request, call_next):
    request.state.raw_body = await request.body()
    response = await call_next(request)
    return response


def find_nearby_workers(lat: float, lng: float, skill: str,
                        radius_km: float = 5, exclude_ids: list = None) -> list[dict]:
    """
    Find available workers near a location with matching skill.
    BEFORE: Firestore geohash queries across 9 cells
    AFTER:  PostGIS ST_DWithin via Supabase RPC — single query, exact distance
    """
    exclude_ids = exclude_ids or []
    radius_meters = int(radius_km * 1000)

    log("matching_service", "find_nearby_workers", "searching",
        lat=lat, lng=lng, skill=skill, radius_km=radius_km)

    workers_data = []
    try:
        result = supabase.rpc("find_nearby_workers", {
            "lat": lat,
            "lng": lng,
            "skill": skill,
            "radius_meters": radius_meters,
        }).execute()
        workers_data = result.data or []
        log("matching_service", "find_nearby_workers", "rpc_result",
            count=len(workers_data))
    except Exception as e:
        error_str = str(e)
        if "PGRST205" in error_str or "Could not find" in error_str:
            # RPC function not deployed — fallback to basic query
            log("matching_service", "find_nearby_workers", "rpc_not_found_fallback",
                severity="WARNING")
            try:
                result = (supabase.table("workers")
                    .select("id, name, phone, rating")
                    .eq("is_available", True)
                    .contains("skills", [skill])
                    .limit(MAX_NOTIFY)
                    .execute())
                workers_data = result.data or []
                # Add dummy distance since we can't calculate without PostGIS
                for w in workers_data:
                    w["distance_meters"] = 0
                log("matching_service", "find_nearby_workers", "fallback_result",
                    count=len(workers_data))
            except Exception as e2:
                log("matching_service", "find_nearby_workers", "fallback_error",
                    severity="ERROR", error=str(e2))
                return []
        else:
            log("matching_service", "find_nearby_workers", "rpc_error",
                severity="ERROR", error=error_str)
            return []

    matched_workers = []
    for worker in workers_data:
        worker_id = str(worker["id"])
        if worker_id in exclude_ids:
            continue

        # Get FCM token from users table
        fcm_token = ""
        try:
            user_result = supabase.table("users").select("fcm_token").eq("id", worker["id"]).single().execute()
            fcm_token = user_result.data.get("fcm_token", "") if user_result.data else ""
        except Exception as e:
            log("matching_service", "find_nearby_workers", "token_lookup_error",
                severity="WARNING", worker_id=worker_id, error=str(e))

        log("matching_service", "find_nearby_workers", "worker_found",
            worker_id=worker_id, has_token=bool(fcm_token),
            token_prefix=fcm_token[:20] if fcm_token else "none")

        matched_workers.append({
            "worker_id": worker_id,
            "distance_km": round(worker.get("distance_meters", 0) / 1000, 2),
            "name": worker.get("name", ""),
            "rating": worker.get("rating", 0),
            "phone": worker.get("phone", ""),
            "fcm_token": fcm_token,
        })

    return matched_workers[:MAX_NOTIFY]


def notify_workers(job_id: str, workers: list[dict], job_details: dict) -> int:
    """
    Send FCM push notifications to all matched workers simultaneously.
    Sets Redis notification state for each worker.
    KEPT: Firebase messaging (FCM) — completely unchanged
    KEPT: Redis state management — completely unchanged
    """
    if not workers:
        return 0

    skill = job_details.get("skill", "Service")
    budget = job_details.get("budget", 0)
    lat = str(job_details.get("lat", 0))
    lng = str(job_details.get("lng", 0))
    description = job_details.get("description", "")

    messages = []
    notified_uids = []

    for worker in workers:
        fcm_token = worker.get("fcm_token", "")
        if not fcm_token:
            log("matching_service", "notify_workers", "skip_no_token",
                worker_id=worker["worker_id"])
            continue

        # Set Redis notification state
        redis_key = f"job_notified:{job_id}:{worker['worker_id']}"
        redis_client.set_state(redis_key, "pending", ex=NOTIFY_TTL)

        distance_str = f"{worker['distance_km']}km away"
        budget_str = f"₹{int(budget)}" if budget else "Market rate"

        message = messaging.Message(
            token=fcm_token,
            notification=messaging.Notification(
                title="New Job Nearby",
                body=f"{skill} job · {budget_str} · {distance_str}",
            ),
            data={
                "type": "JOB_OFFER",
                "job_id": job_id,
                "skill": skill,
                "budget": str(budget),
                "lat": lat,
                "lng": lng,
                "description": description[:200],
                "distance_km": str(worker["distance_km"]),
                "timeout_seconds": str(NOTIFY_TTL),
            },
            android=messaging.AndroidConfig(
                priority="high",
                ttl=NOTIFY_TTL,
            ),
        )
        messages.append(message)
        notified_uids.append(worker["worker_id"])

    if not messages:
        return 0

    # Send all notifications simultaneously
    sent_count = 0
    try:
        response = messaging.send_each(messages)
        sent_count = response.success_count
        log("matching_service", "notify_workers", "sent",
            job_id=job_id, total=len(messages),
            success=response.success_count, failure=response.failure_count)

        # Log individual failures
        for i, send_resp in enumerate(response.responses):
            if send_resp.exception:
                log("matching_service", "notify_workers", "individual_fail",
                    severity="WARNING",
                    worker_id=notified_uids[i] if i < len(notified_uids) else "?",
                    error=str(send_resp.exception))
    except Exception as e:
        log("matching_service", "notify_workers", "send_error",
            severity="ERROR", error=str(e))

    # Update job with notified workers list
    try:
        supabase.table("jobs").update({
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", job_id).execute()
    except Exception as e:
        log("matching_service", "notify_workers", "db_update_error",
            severity="WARNING", error=str(e))

    return sent_count


@app.post("/internal/match")
def match_workers(request: Request):
    """
    BEFORE: Pub/Sub push subscription trigger
    AFTER:  Direct HTTP call from outbox dispatcher via pg_net

    1. Searches PostGIS for available workers with matching skills.
    2. Sends simultaneous FCM push notifications to all matched workers.
    3. Updates job document with match results.
    """
    try:
        verify_internal_secret(request)
        raw = request.state.raw_body
        payload = json.loads(raw)

        job_id = payload.get("job_id")
        event_payload = payload.get("payload", {})
        skill = event_payload.get("skill", "")
        lat = event_payload.get("lat", 0)
        lng = event_payload.get("lng", 0)
        radius_km = event_payload.get("radius_km", 5)
        budget = event_payload.get("budget", 0)
        description = event_payload.get("description", "")

        if not job_id or not skill:
            log("matching_service", "match_workers", "missing_fields",
                severity="WARNING", job_id=job_id)
            return {"status": "skipped", "reason": "missing job_id or skill"}

        # Exclude previously notified workers (for re-match after rejections)
        exclude_ids = event_payload.get("exclude_workers", [])

        # Step 1: Find nearby workers via PostGIS
        matched_workers = find_nearby_workers(
            lat, lng, skill,
            radius_km=radius_km,
            exclude_ids=exclude_ids,
        )

        # Step 2: Update job with match results
        worker_ids = [w["worker_id"] for w in matched_workers]
        status = "matched" if worker_ids else "open"

        supabase.table("jobs").update({
            "status": status,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", job_id).execute()

        # Step 3: Send FCM blast to matched workers
        sent_count = 0
        if matched_workers:
            job_details = {
                "skill": skill,
                "budget": budget,
                "lat": lat,
                "lng": lng,
                "description": description,
            }
            sent_count = notify_workers(job_id, matched_workers, job_details)

        log("matching_service", "match_workers", "complete",
            job_id=job_id, skill=skill,
            matched=len(worker_ids), notified=sent_count)

        return {
            "status": "ok",
            "job_id": job_id,
            "matched_workers": len(worker_ids),
            "notified": sent_count,
        }

    except HTTPException:
        raise
    except Exception as e:
        log("matching_service", "match_workers", "unexpected_error",
            severity="ERROR", error=str(e), trace=traceback.format_exc())
        raise HTTPException(500, "Internal server error")
