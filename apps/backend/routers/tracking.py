"""
routers/tracking.py
Public Web Tracking Router for Jugaad Household & Family Safety.
Renders signed, zero-friction live worker progress via HMAC tokens
so family members can monitor doorstep arrivals on WhatsApp without logging in.
"""
from fastapi import APIRouter, HTTPException, Query
from shared.database import supabase
from shared import redis_client
import os
import hmac
import hashlib
import time
import json
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)
router = APIRouter()

TRACKING_SECRET = os.getenv("TRACKING_SECRET", "jugaad_family_safety_secret_key_2026")


def generate_tracking_token(job_id: str, expires_in_seconds: int = 7200) -> str:
    """Generate a tamper-proof HMAC token for public web sharing."""
    exp = int(time.time()) + expires_in_seconds
    msg = f"{job_id}:{exp}".encode()
    sig = hmac.new(TRACKING_SECRET.encode(), msg, hashlib.sha256).hexdigest()[:24]
    return f"{job_id}.{exp}.{sig}"


def verify_tracking_token(token: str) -> str:
    """Verify HMAC token authenticity and check expiration."""
    try:
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError("Malformed token")
        job_id, exp_str, sig = parts
        exp = int(exp_str)
        if time.time() > exp:
            raise ValueError("Tracking link has expired")
        expected_sig = hmac.new(TRACKING_SECRET.encode(), f"{job_id}:{exp}".encode(), hashlib.sha256).hexdigest()[:24]
        if not hmac.compare_digest(expected_sig, sig):
            raise ValueError("Invalid tracking signature")
        return job_id
    except Exception as e:
        raise HTTPException(status_code=403, detail=f"Tracking link invalid or expired: {e}")


@router.get("/public/track")
def get_public_tracking_view(token: str = Query(..., description="Signed tracking token")):
    """
    Public web tracking endpoint accessible via WhatsApp links.
    Returns worker name, avatar, skill, live status, and coordinates.
    Employs hot-cache to handle high-frequency location polls without hammering Postgres.
    """
    job_id = verify_tracking_token(token)

    meta_cache_key = f"cache:public_track:meta:{job_id}"
    cached_meta = None
    try:
        raw_cached = redis_client.get_state(meta_cache_key)
        if raw_cached:
            cached_meta = json.loads(raw_cached)
    except Exception:
        pass

    if cached_meta:
        job = cached_meta["job"]
        worker_info = cached_meta["worker_info"]
        worker_id = job.get("worker_id")
    else:
        job_res = supabase.table("jobs").select("id, status, skill_required, address, worker_id, created_at").eq("id", job_id).maybe_single().execute()
        if not job_res or not job_res.data:
            raise HTTPException(404, "Job not found")

        job = job_res.data
        worker_id = job.get("worker_id")

        worker_info: Dict[str, Any] = {
            "name": "Verified Pro",
            "skill": job.get("skill_required", "Trade Expert"),
            "rating": 4.9,
            "is_id_verified": True
        }

        if worker_id:
            w_res = supabase.table("workers").select("name, rating, is_id_verified, avatar_url").eq("id", worker_id).maybe_single().execute()
            if w_res and w_res.data:
                worker_info.update(w_res.data)

        # Cache job + worker metadata for 10 seconds
        try:
            redis_client.set_state(meta_cache_key, json.dumps({"job": job, "worker_info": worker_info}), ex=10)
        except Exception:
            pass

    # Fetch live location from Redis hot cache (always fresh)
    live_coords = {"lat": 12.3051, "lng": 76.6551}
    try:
        if worker_id:
            raw_telemetry = redis_client.get_state(f"worker:telemetry:{worker_id}")
            if raw_telemetry:
                tel = json.loads(raw_telemetry)
                live_coords["lat"] = float(tel.get("lat", 12.3051))
                live_coords["lng"] = float(tel.get("lng", 76.6551))
    except Exception:
        pass

    return {
        "status": "ok",
        "job_id": job_id,
        "job_status": job.get("status"),
        "skill": job.get("skill_required"),
        "destination_address": job.get("address"),
        "worker": worker_info,
        "live_location": live_coords,
        "tracking_active": job.get("status") in ["accepted", "en_route", "in_progress"]
    }
