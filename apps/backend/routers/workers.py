from fastapi import APIRouter, Depends, HTTPException, Request, Header
from shared.auth import verify_firebase_token
from shared.database import supabase
from datetime import datetime, timezone
import logging
from typing import List, Optional
from pydantic import BaseModel
from collections import defaultdict
import time
import json
from shared.models import FCMTokenUpdate

logger = logging.getLogger(__name__)
router = APIRouter()

def verify_admin_user(uid: str = Depends(verify_firebase_token)) -> str:
    res = supabase.table("users").select("id, role").eq("firebase_uid", uid).maybe_single().execute()
    if not res or not res.data:
        res = supabase.table("users").select("id, role").eq("id", uid).maybe_single().execute()
    if not res or not res.data:
        raise HTTPException(status_code=403, detail="User not found")
    if res.data.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Access denied: admin role required")
    return res.data["id"]

@router.post("/{worker_id}/approve")
async def approve_worker_endpoint(worker_id: str, admin_id: str = Depends(verify_admin_user)):
    # Call Supabase RPC approve_worker
    res = supabase.rpc("approve_worker", {"p_worker_id": worker_id}).execute()
    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Worker not found or approve RPC failed")
    
    # Send FCM notification
    from services.fcm_service import fcm_service
    await fcm_service.send_notification(
        user_id=worker_id,
        title="Registration Approved 🎉",
        body="Congratulations! Your registration has been approved. You are now online and visible to users.",
        data={"type": "APPROVAL_STATUS", "status": "approved"}
    )
    return {"status": "success", "message": "Worker profile approved and FCM notification sent"}

@router.post("/{worker_id}/reject")
async def reject_worker_endpoint(worker_id: str, admin_id: str = Depends(verify_admin_user)):
    # Call Supabase RPC reject_worker
    res = supabase.rpc("reject_worker", {"p_worker_id": worker_id}).execute()
    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Worker not found or reject RPC failed")
    
    # Send FCM notification
    from services.fcm_service import fcm_service
    await fcm_service.send_notification(
        user_id=worker_id,
        title="Registration Update",
        body="Your registration was not approved. Please contact support for more information.",
        data={"type": "APPROVAL_STATUS", "status": "rejected"}
    )
    return {"status": "success", "message": "Worker profile rejected and FCM notification sent"}


import re

def mask_phone_number(raw_phone: Optional[str]) -> Optional[str]:
    """
    Masks a raw 10-digit or 12-digit Indian phone number for public/search API responses.
    Example: '9988776655' or '+919988776655' -> '+91 99*** ***55'
    Returns None if raw_phone is empty or None.
    """
    if not raw_phone:
        return None
    cleaned = re.sub(r'[\s\-\+]', '', str(raw_phone))
    if cleaned.startswith('91') and len(cleaned) == 12:
        cleaned = cleaned[2:]
    if len(cleaned) == 10:
        first2 = cleaned[:2]
        last2 = cleaned[-2:]
        return f"+91 {first2}*** ***{last2}"
    return "+91 ***** *****"


@router.get("/{worker_id}/public-profile")
def get_worker_public_profile(worker_id: str):
    """
    Returns the audited, safe public profile of an approved worker.
    Includes aggregate rating, total completed jobs, member-since date,
    and recent review snippets.
    Excludes sensitive/internal fields (documents, Aadhaar, rejection_reason, internal notes).
    Exposes only phone_masked — raw phone is removed from public payload.
    """
    res = supabase.table("workers").select("*").eq("id", worker_id).maybe_single().execute()
    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Worker not found")
    
    worker = res.data
    st = str(worker.get("status") or worker.get("approval_status") or "").lower()
    if st != "approved":
        raise HTTPException(status_code=404, detail="Approved worker profile not found")

    recent_reviews = []
    try:
        rev_res = supabase.table("reviews").select("rating, comment, created_at, reviewer_id").eq("reviewee_id", worker_id).order("created_at", desc=True).limit(3).execute()
        for rev in (rev_res.data or []):
            reviewer_name = "Customer"
            if rev.get("reviewer_id"):
                try:
                    u_res = supabase.table("users").select("name").eq("id", rev["reviewer_id"]).maybe_single().execute()
                    if u_res and u_res.data and u_res.data.get("name"):
                        reviewer_name = u_res.data["name"]
                except Exception:
                    pass
            recent_reviews.append({
                "reviewer_name": reviewer_name,
                "rating": rev.get("rating"),
                "comment": rev.get("comment"),
                "created_at": rev.get("created_at"),
            })
    except Exception as e:
        logger.warning(f"Failed to fetch worker reviews: {e}")

    profile_photo = worker.get("profile_photo")
    if not profile_photo and worker.get("documents"):
        for doc in (worker.get("documents") or []):
            if isinstance(doc, dict) and doc.get("name") == "profile_photo":
                profile_photo = doc.get("url")
                break
    if not profile_photo:
        profile_photo = worker.get("id_document_url")

    total_completed = int(
        worker.get("total_completed_jobs") or worker.get("total_jobs") or worker.get("totalJobsCompleted") or 0
    )

    raw_rating = worker.get("rating")
    if total_completed == 0 or raw_rating is None or float(raw_rating) == 0.0 or not recent_reviews:
        rating_val = None
    else:
        rating_val = float(raw_rating)

    raw_phone = worker.get("phone") or ""
    phone_masked = mask_phone_number(raw_phone)

    return {
        "id": worker["id"],
        "name": worker.get("name") or "Worker",
        "phone_masked": phone_masked,
        "skills": worker.get("skills") or [],
        "specialities": worker.get("specialities") or [],
        "area": worker.get("area") or "Mysuru",
        "hourly_rate": float(worker.get("hourly_rate") or worker.get("rate_per_hour") or 150.0),
        "rating": rating_val,
        "total_completed_jobs": total_completed,
        "is_verified": bool(worker.get("is_verified", worker.get("isVerified", worker.get("id_verified", True)))),
        "is_available": bool(worker.get("is_available", True)),
        "created_at": worker.get("created_at"),
        "profile_photo": profile_photo,
        "experience": worker.get("experience") or "1+ years",
        "bio": worker.get("bio") or "Verified local professional worker in Mysuru.",
        "recent_reviews": recent_reviews,
    }



@router.get("/me")
def get_worker_profile(uid: str = Depends(verify_firebase_token)):
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="Worker not found")

    worker_id = user_result.data["id"]
    result = supabase.table("workers").select("*").eq("id", worker_id).single().execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Worker not found")
    return result.data

@router.put("/me")
def update_worker_profile(profile: dict, uid: str = Depends(verify_firebase_token)):
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not user_result or not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    worker_id = user_result.data["id"]

    # Filter out protected fields to prevent privilege escalation or metric tampering
    PROTECTED_FIELDS = {"approval_status", "status", "rating", "total_jobs", "total_completed_jobs", "strikes", "suspended", "id", "is_verified"}
    safe_profile = {k: v for k, v in profile.items() if k not in PROTECTED_FIELDS}

    if "lat" in safe_profile and "lng" in safe_profile:
        safe_profile["location"] = f"POINT({safe_profile.pop('lng')} {safe_profile.pop('lat')})"

    safe_profile["updated_at"] = datetime.now(timezone.utc).isoformat()
    supabase.table("workers").update(safe_profile).eq("id", worker_id).execute()
    return {"status": "success", "message": "Worker profile updated"}

@router.post("/me/id-doc")
def upload_id_doc(doc_url: str, uid: str = Depends(verify_firebase_token)):
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    worker_id = user_result.data["id"]

    supabase.table("workers").update({
        "id_document_url": doc_url,
        "id_verified": False,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", worker_id).execute()
    return {"status": "success", "message": "ID Document submitted for review"}

@router.post("/{worker_id}/heartbeat")
def worker_heartbeat(worker_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != worker_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="User not found")
    internal_id = user_result.data["id"]

    lat = payload.get("lat")
    lng = payload.get("lng")
    updates = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if "is_available" in payload:
        updates["is_available"] = payload["is_available"]

    if lat is not None and lng is not None:
        updates["location"] = f"POINT({lng} {lat})"

    # Antigravity strike reset: if last_strike_at is older than 30 days, reset strikes and suspended state.
    try:
        worker_data_res = supabase.table("workers").select("strikes, last_strike_at, suspended, approval_status").eq("id", internal_id).maybe_single().execute()
        if worker_data_res and worker_data_res.data:
            w_data = worker_data_res.data
            strikes = w_data.get("strikes", 0) or 0
            last_strike_at_str = w_data.get("last_strike_at")
            
            if strikes > 0 and last_strike_at_str:
                last_strike_at = datetime.fromisoformat(last_strike_at_str.replace("Z", "+00:00"))
                now = datetime.now(timezone.utc)
                if (now - last_strike_at).days >= 30:
                    # Reset strikes and suspended status
                    reset_updates = {
                        "strikes": 0,
                        "suspended": False,
                        "updated_at": now.isoformat()
                    }
                    if w_data.get("approval_status") == "suspended":
                        reset_updates["approval_status"] = "approved"
                        reset_updates["is_available"] = True
                        
                    supabase.table("workers").update(reset_updates).eq("id", internal_id).execute()
                    logger.info(f"Antigravity: Reset strikes for worker {internal_id} due to 30 days of good behavior.")
    except Exception as reset_err:
        logger.error(f"Antigravity: Failed to check/reset worker strikes: {reset_err}")

    supabase.table("workers").update(updates).eq("id", internal_id).execute()
    return {"status": "success"}


@router.post("/{worker_id}/fcm-token")
def worker_fcm_token(worker_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != worker_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    token = payload.get("token")
    if token:
        supabase.table("users").update({
            "fcm_token": token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("firebase_uid", worker_id).execute()
    return {"status": "success"}

# --- Rate Limiting Cache & Store ---
rate_limit_store = defaultdict(list)

def is_rate_limited(user_id: str, limit: int = 10, window: int = 60) -> bool:
    """Distributed rate limiting (10 req/min) using Redis with memory fallback."""
    now = time.time()
    r = redis_client.get_client()
    if r:
        try:
            key = f"rate_limit:worker_search:{user_id}"
            r.zremrangebyscore(key, 0, now - window)
            current_requests = r.zcard(key)
            if current_requests >= limit:
                return True
            r.zadd(key, {str(now): now})
            r.expire(key, window)
            return False
        except Exception as e:
            logger.error(f"Redis rate limiting error: {e}")
    
    # Fallback to in-memory
    rate_limit_store[user_id] = [t for t in rate_limit_store[user_id] if now - t < window]
    if len(rate_limit_store[user_id]) >= limit:
        return True
    rate_limit_store[user_id].append(now)
    return False

# --- Pydantic Response Models ---
class WorkerSearchResponse(BaseModel):
    """Single worker result from a spatial search."""
    id: str
    name: str
    phone_masked: Optional[str] = None
    service_types: List[str]       # Worker skills array
    rating: Optional[float] = None
    distance_meters: float         # Geodesic distance from user's location
    is_available: bool
    profile_photo: Optional[str] = None
    completed_jobs: int = 0
    emergency_available: bool = False


class WorkerSearchListResponse(BaseModel):
    """Paginated search results with auto-radius expansion metadata."""
    workers: List[WorkerSearchResponse]
    total: int
    page: int
    has_more: bool
    radius_km: float               # Actual radius used (may differ from requested if expanded)
    expanded_radius: bool = False   # True if radius was auto-expanded due to zero results


class LocationUpdateRequest(BaseModel):
    """Request body for updating worker's GPS coordinates."""
    lat: float
    lng: float
    is_available: Optional[bool] = True


# ─── Auto-Radius Expansion Config ─────────────────────────────────────────
# Uber-style: if no workers found in the initial radius, automatically
# expand once to EXPANDED_RADIUS_KM and retry. This avoids showing
# "no workers found" when workers exist just outside the requested radius.
# Values are now read from the platform_config table (admin-managed),
# with hardcoded fallbacks for backward compatibility.
_FALLBACK_DEFAULT_RADIUS = 5.0
_FALLBACK_EXPANDED_RADIUS = 10.0

def _get_radius_config():
    """Read dispatch radius from platform_config table. Returns (default_km, expanded_km)."""
    try:
        result = supabase.table("platform_config").select("dispatch_radius_km, expanded_radius_km").eq("id", 1).maybe_single().execute()
        if result and result.data:
            return (
                float(result.data.get("dispatch_radius_km", _FALLBACK_DEFAULT_RADIUS)),
                float(result.data.get("expanded_radius_km", _FALLBACK_EXPANDED_RADIUS)),
            )
    except Exception as e:
        logger.warning(f"Could not read platform_config for radius (using defaults): {e}")
    return (_FALLBACK_DEFAULT_RADIUS, _FALLBACK_EXPANDED_RADIUS)

# Module-level aliases kept for any code that references them directly
DEFAULT_RADIUS_KM = _FALLBACK_DEFAULT_RADIUS
EXPANDED_RADIUS_KM = _FALLBACK_EXPANDED_RADIUS


def _execute_spatial_search(
    lat: float,
    lng: float,
    radius_km: float,
    service_type: Optional[str],
    page: int,
    limit: int,
) -> list:
    """
    Call the search_nearby_workers PostGIS RPC function.
    Returns raw list of worker dicts from Supabase.
    """
    result = supabase.rpc("search_nearby_workers", {
        "user_lat": lat,
        "user_lng": lng,
        "radius_km": radius_km,
        "job_category": service_type or "",
        "p_page": page,
        "p_limit": limit,
    }).execute()
    return result.data or []


def _format_worker_results(workers_data: list, page: int, limit: int, radius_km: float, expanded: bool) -> dict:
    """Format raw RPC results into the API response shape."""
    total = workers_data[0]["total_count"] if len(workers_data) > 0 else 0
    has_more = (page + 1) * limit < total

    workers_list = []
    for w in workers_data:
        workers_list.append({
            "id": w["id"],
            "name": w.get("name") or "Worker",
            "phone": w.get("phone"),
            "service_types": w.get("skills") or [],
            "rating": float(w.get("rating") or 0.0),
            "distance_meters": float(w.get("distance_meters") or 0.0),
            "is_available": w.get("is_available", True),
            "profile_photo": w.get("profile_photo"),
            "completed_jobs": int(w.get("completed_jobs") or 0),
            "emergency_available": w.get("emergency_available", False),
        })

    return {
        "workers": workers_list,
        "total": total,
        "page": page,
        "has_more": has_more,
        "radius_km": radius_km,
        "expanded_radius": expanded,
    }


RADIUS_TIERS_METERS = [3000, 7000, 15000, 25000]

def _parse_wkb_point(wkb_hex: str):
    """Parse lat, lng from PostGIS EWKB / WKB hex representation."""
    if not wkb_hex or not isinstance(wkb_hex, str) or len(wkb_hex) < 42:
        return None, None
    try:
        import struct
        data = bytes.fromhex(wkb_hex)
        byte_order = '<' if data[0] == 1 else '>'
        geom_type = struct.unpack(f'{byte_order}I', data[1:5])[0]
        offset = 5
        if geom_type & 0x20000000:
            offset += 4
        lng, lat = struct.unpack(f'{byte_order}dd', data[offset:offset+16])
        return lat, lng
    except Exception:
        return None, None

def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate geodesic distance in meters between two lat/lng coordinates."""
    import math
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


@router.get("/search")
def search_workers(
    category: Optional[str] = None,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    service_type: Optional[str] = None,
    radius_km: Optional[float] = None,
    page: int = 0,
    limit: int = 20,
):
    """
    Hyperlocal Worker Search Endpoint for Mysuru with Tiered-Radius (Nearest-First)
    and City-Wide Rating Fallback.

    Required Behavior (Priority Order):
      Priority 1 — Nearest worker(s) first:
        Searches for active and available workers matching the requested category within
        expanding radius tiers: 3000m (3km) → 7000m (7km) → 15000m (15km) → 25000m (25km)
        around the user's lat/lng. Results are ordered by ST_Distance / Haversine distance ascending
        so the closest worker always shows first.

      Priority 2 — Fallback when nobody is nearby:
        If zero workers are found even at the max radius (25km, covering all of Mysuru),
        automatically falls back to a city-wide query for all workers of that category in Mysuru,
        with no distance filter.

      Priority 3 — Fallback ordering = rating-based:
        In the city-wide fallback case, results are ordered by:
        rating DESC, total_completed_jobs DESC, is_verified DESC.

    Filtering:
      - work_category = requested_category (or matching skills / specialities)
      - is_active = true and is_available = true
      - City/service-area boundary = Mysuru

    Response Shape:
      {
        "mode": "nearest" | "citywide_rating_fallback" | "no_workers_found",
        "radius_used_m": 7000, # present when mode == "nearest"
        "count": 5,
        "workers": [
          {
            "id": "uuid",
            "name": "Ramesh K",
            "category": "plumber",
            "rating": 4.7,
            "distance_m": 2140, # null in fallback if distance is N/A
            "is_verified": true
          }
        ]
      }
    """
    req_category = category or service_type
    if not req_category or not str(req_category).strip():
        raise HTTPException(status_code=400, detail="Category parameter is required.")

    if lat is None or lng is None:
        raise HTTPException(
            status_code=400,
            detail="Latitude and longitude parameters (lat, lng) are required and must be valid coordinates."
        )

    try:
        lat = float(lat)
        lng = float(lng)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Invalid coordinates. Lat and Lng must be numbers.")

    if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lng <= 180.0):
        raise HTTPException(
            status_code=400,
            detail="Invalid coordinates. Lat must be in [-90, 90], Lng must be in [-180, 180]."
        )

    req_category = str(req_category).strip().lower()

    # ── 1. Redis Response Cache check (30s TTL) ──
    cache_key = f"cache:worker_search_priority:{req_category}:{round(lat, 3)}:{round(lng, 3)}"
    r = redis_client.get_client()
    if r:
        try:
            cached = r.get(cache_key)
            if cached:
                logger.info(f"Returning cached search results for key {cache_key}")
                return json.loads(cached)
        except Exception as cache_err:
            logger.error(f"Redis cache retrieve error: {cache_err}")

    # ── 2. Priority 1: PostGIS RPC execution attempt (find_nearby_workers) ──
    for radius_m in RADIUS_TIERS_METERS:
        try:
            rpc_res = supabase.rpc("find_nearby_workers", {
                "lat": lat,
                "lng": lng,
                "skill": req_category,
                "radius_meters": int(radius_m)
            }).execute()
            workers_data = rpc_res.data or []
            if workers_data:
                w_ids = [str(w["id"]) for w in workers_data if "id" in w]
                status_map = {}
                if w_ids:
                    try:
                        st_res = supabase.table("workers").select("id, status, approval_status").in_("id", w_ids).execute()
                        for row in (st_res.data or []):
                            status_map[str(row["id"])] = str(row.get("status") or row.get("approval_status") or "pending_approval").lower()
                    except Exception:
                        pass

                formatted_workers = []
                for w in workers_data:
                    wid = str(w["id"])
                    w_st = status_map.get(wid) or str(w.get("status") or w.get("approval_status") or "pending_approval").lower()
                    if w_st != "approved":
                        continue
                    dist_val = w.get("distance_meters") or w.get("distance_m") or 0.0
                    formatted_workers.append({
                        "id": wid,
                        "name": w.get("name") or "Worker",
                        "category": req_category,
                        "rating": float(w.get("rating") or 0.0),
                        "distance_m": int(round(float(dist_val))),
                        "is_verified": bool(w.get("is_verified", w.get("isVerified", True))),
                    })
                
                if formatted_workers:
                    formatted_workers.sort(key=lambda x: x["distance_m"])
                    formatted_workers = formatted_workers[:20]

                    response_data = {
                        "mode": "nearest",
                        "radius_used_m": radius_m,
                        "count": len(formatted_workers),
                        "workers": formatted_workers
                    }
                    if r:
                        try:
                            r.set(cache_key, json.dumps(response_data), ex=30)
                        except Exception:
                            pass
                    return response_data
        except Exception as rpc_err:
            logger.debug(f"RPC find_nearby_workers failed for tier {radius_m}: {rpc_err}")
            break

    # ── 3. Database Direct Query Engine (Fallback if RPC not used or returns 0 in tiers) ──
    try:
        db_res = supabase.table("workers").select("*").execute()
        all_rows = db_res.data or []
    except Exception as db_err:
        logger.error(f"Failed to query workers table: {db_err}")
        raise HTTPException(status_code=500, detail="Database query failed.")

    matching_workers = []
    for w in all_rows:
        w_cat = str(w.get("work_category") or w.get("category") or "").lower()
        w_skills = [str(s).lower() for s in (w.get("skills") or [])]
        w_specs = [str(s).lower() for s in (w.get("specialities") or [])]

        if req_category in ["", "all", "none"]:
            cat_match = True
        else:
            cat_match = (
                w_cat == req_category or
                req_category in w_cat or
                w_cat in req_category or
                any(req_category in s or s in req_category for s in w_skills) or
                any(req_category in s or s in req_category for s in w_specs)
            )
        if not cat_match:
            continue

        is_act = w.get("is_active", True)
        if is_act is None: is_act = True
        is_avail = w.get("is_available", True)
        if is_avail is None: is_avail = True

        if not (is_act and is_avail):
            continue

        w_st = str(w.get("status") or w.get("approval_status") or "approved").lower()
        if w_st not in ["approved", "verified", "active"]:
            continue

        loc_val = w.get("location")
        w_lat, w_lng = None, None
        if isinstance(loc_val, str):
            w_lat, w_lng = _parse_wkb_point(loc_val)
            if w_lat is None and "POINT(" in loc_val:
                try:
                    coords = loc_val.replace("POINT(", "").replace(")", "").strip().split()
                    w_lng, w_lat = float(coords[0]), float(coords[1])
                except Exception:
                    pass

        dist_m = None
        if w_lat is not None and w_lng is not None:
            dist_m = _haversine_m(lat, lng, w_lat, w_lng)

        w_jobs = int(w.get("total_completed_jobs") or w.get("total_jobs") or w.get("totalJobsCompleted") or 0)
        w_raw_rating = w.get("rating")
        w_rating = float(w_raw_rating) if (w_raw_rating is not None and float(w_raw_rating) > 0.0) else 4.8
        w_masked_phone = mask_phone_number(w.get("phone"))

        w_dict = {
            "id": str(w.get("id") or ""),
            "name": w.get("name") or "Verified Worker",
            "category": w.get("category") or w.get("work_category") or req_category,
            "phone_masked": w_masked_phone,
            "rating": w_rating,
            "total_completed_jobs": w_jobs,
            "is_verified": bool(w.get("is_verified", w.get("isVerified", w.get("id_verified", True)))),
            "city": w.get("city") or "Mysuru",
            "area": w.get("area") or "Mysuru",
            "distance_m": dist_m,
        }
        matching_workers.append(w_dict)

    # Priority 1 — Nearest expanding radius search
    for radius in RADIUS_TIERS_METERS:
        tier_workers = [
            w for w in matching_workers
            if w["distance_m"] is not None and w["distance_m"] <= radius
        ]
        if tier_workers:
            tier_workers.sort(key=lambda x: x["distance_m"])
            formatted = [
                {
                    "id": w["id"],
                    "name": w["name"],
                    "category": w["category"],
                    "phone_masked": w["phone_masked"],
                    "rating": w["rating"],
                    "distance_m": int(round(w["distance_m"])),
                    "is_verified": w["is_verified"],
                }
                for w in tier_workers[:20]
            ]
            response_data = {
                "mode": "nearest",
                "radius_used_m": radius,
                "count": len(formatted),
                "workers": formatted,
            }
            if r:
                try:
                    r.set(cache_key, json.dumps(response_data), ex=30)
                except Exception:
                    pass
            return response_data

    # Priority 2 & 3 — City-wide rating fallback
    city_workers = [
        w for w in matching_workers
        if (w.get("city") or "mysuru").lower() == "mysuru" or "mysuru" in (w.get("area") or "").lower()
    ]
    if not city_workers:
        city_workers = matching_workers

    if city_workers:
        city_workers.sort(
            key=lambda x: (
                x["rating"] if x["rating"] is not None else -1.0,
                x["total_completed_jobs"],
                1 if x["is_verified"] else 0
            ),
            reverse=True
        )
        formatted_fallback = [
            {
                "id": w["id"],
                "name": w["name"],
                "category": w["category"],
                "phone_masked": w["phone_masked"],
                "rating": w["rating"],
                "distance_m": None,  # Explicitly null in fallback mode per contract
                "is_verified": w["is_verified"],
            }
            for w in city_workers[:20]
        ]
        response_data = {
            "mode": "citywide_rating_fallback",
            "count": len(formatted_fallback),
            "workers": formatted_fallback,
        }
        if r:
            try:
                r.set(cache_key, json.dumps(response_data), ex=30)
            except Exception:
                pass
        return response_data


    # Category has zero workers in entire city
    response_data = {
        "mode": "no_workers_found",
        "count": 0,
        "workers": [],
    }
    if r:
        try:
            r.set(cache_key, json.dumps(response_data), ex=30)
        except Exception:
            pass
    return response_data


# ─── Legacy POST /search support ──────────────────────────────────────────
@router.post("/search")
def search_workers_legacy(payload: dict):
    """Legacy POST endpoint for backward compatibility with older Flutter clients."""
    return search_workers(
        category=payload.get("category") or payload.get("skill") or payload.get("service_type"),
        lat=payload.get("lat"),
        lng=payload.get("lng"),
    )


# ─── PATCH /location — Worker Location Update ────────────────────────────
@router.patch("/location")
def update_worker_location(
    payload: LocationUpdateRequest,
    uid: str = Depends(verify_firebase_token),
):
    """
    Update the authenticated worker's GPS location in Supabase.

    Called when a worker goes online or updates their position.
    Uses the update_worker_location PostGIS RPC function which atomically:
      1. Sets location = ST_MakePoint(lng, lat)::GEOGRAPHY
      2. Sets is_available and is_online flags
      3. Updates the updated_at timestamp

    Workers are NOT moving in real-time — they update location once when
    they come online (sitting at home/shop). The heartbeat service
    refreshes this every 15 minutes.
    """
    logger.info(f"Worker location update: uid={uid}, lat={payload.lat}, lng={payload.lng}")

    # Validate coordinates are within India bounding box (rough sanity check)
    if not (6.0 <= payload.lat <= 37.0) or not (68.0 <= payload.lng <= 97.5):
        logger.warning(f"Suspicious coordinates from worker {uid}: lat={payload.lat}, lng={payload.lng}")
        # Don't reject — they might be testing from outside India — but log it

    # Resolve the internal worker ID from Firebase UID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    if not user_result.data:
        raise HTTPException(status_code=404, detail="Worker not found")
    worker_id = user_result.data["id"]

    try:
        # Try the RPC function first (atomic PostGIS update)
        result = supabase.rpc("update_worker_location", {
            "p_worker_id": worker_id,
            "p_lat": payload.lat,
            "p_lng": payload.lng,
            "p_available": payload.is_available,
        }).execute()

        if result.data is True:
            logger.info(f"Worker {worker_id} location updated via RPC: ({payload.lat}, {payload.lng})")
            return {
                "status": "success",
                "message": "Location updated",
                "location": {"lat": payload.lat, "lng": payload.lng},
            }
        else:
            raise HTTPException(status_code=404, detail="Worker record not found in database")

    except HTTPException:
        raise
    except Exception as e:
        logger.warning(f"RPC update_worker_location failed: {e}. Falling back to direct update.")

        # Fallback: direct table update with WKT string
        try:
            supabase.table("workers").update({
                "location": f"POINT({payload.lng} {payload.lat})",
                "is_available": payload.is_available,
                "is_online": True,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", worker_id).execute()

            return {
                "status": "success",
                "message": "Location updated (fallback)",
                "location": {"lat": payload.lat, "lng": payload.lng},
            }
        except Exception as fallback_err:
            logger.error(f"Fallback location update also failed: {fallback_err}")
            raise HTTPException(status_code=500, detail=f"Failed to update location: {str(e)}")


@router.patch("/me/fcm-token")
@router.post("/me/fcm-token")
async def update_worker_fcm_token(body: FCMTokenUpdate, uid: str = Depends(verify_firebase_token)):
    w_res = supabase.table("workers").select("id").eq("firebase_uid", uid).maybe_single().execute()
    if not w_res or not w_res.data:
        w_res = supabase.table("workers").select("id").eq("id", uid).maybe_single().execute()
    if not w_res or not w_res.data:
        raise HTTPException(404, detail="Worker profile not found")
    worker_id = w_res.data["id"]
    supabase.table("workers").update({"fcm_token": body.fcm_token, "updated_at": datetime.now(timezone.utc).isoformat()}).eq("id", worker_id).execute()
    return {"status": "success", "message": "FCM token updated successfully"}


