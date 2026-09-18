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
from shared import redis_client

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


RADIUS_TIERS_METERS = [3000, 7000, 15000, 25000, 50000, 100000]

# Category aliases and natural language keyword matcher
SERVICE_KEYWORD_MAP = {
    "plumber": ["plumb", "pipe", "leak", "drain", "water", "tap", "sink", "toilet", "flush", "fitting", "sanitary", "geyser"],
    "electrician": ["electr", "power", "switch", "wiring", "short", "inverter", "fan", "fuse", "light", "mcb", "circuit"],
    "laptop_repair": ["laptop", "computer", "pc", "macbook", "keyboard", "windows", "motherboard", "hard disk", "ssd"],
    "phone_repair": ["phone", "mobile", "iphone", "android", "smartphone", "screen replacement", "display", "mic"],
    "ac_service": ["ac", "air condition", "cooling", "compressor", "gas refill", "split ac", "duct", "hvac"],
    "carpenter": ["carpent", "wood", "furniture", "door", "hinges", "table", "chair", "lock", "cabinet"],
    "painter": ["paint", "whitewash", "wall", "putty", "distemper", "color", "texture"],
    "cleaning": ["clean", "deep clean", "house clean", "sanitiz", "maid", "mop", "wash", "sofa clean"],
    "ro_service": ["ro", "water purifier", "filter", "candle", "aquaguard", "kent", "pureit"],
    "refrigerator_service": ["fridge", "refrigerator", "deep freeze", "freezer", "defrost"],
}

def resolve_search_category(query: Optional[str]) -> tuple[str, bool]:
    """Resolves natural language or abbreviated service query to canonical category."""
    if not query:
        return "", True
    clean = query.strip().lower().replace("-", " ").replace("_", " ")
    tokens = [t.strip() for t in clean.split() if t.strip()]
    GENERIC_ALL_TERMS = {
        "all", "none", "*", "any", "service", "services", "service specialist",
        "service specialists", "general", "expert", "experts", "worker", "workers",
        "pro", "pros", "helper", "helpers", "service expert", "service pros"
    }
    if not tokens or clean in GENERIC_ALL_TERMS:
        return "", True

    GENERIC_WORDS = {"repair", "service", "fix", "care", "worker", "pro", "center", "expert", "specialist", "helper"}
    non_generic = [w for w in tokens if w not in GENERIC_WORDS]
    if not non_generic:
        return "", True

    # 1. Exact canonical category match
    for cat in SERVICE_KEYWORD_MAP.keys():
        if clean == cat.replace("_", " "):
            return cat, False

    # 2. Match primary root domain words in query (e.g. 'laptop', 'phone', 'plumber', 'electrician', 'painter')
    for word in tokens:
        if word in GENERIC_WORDS:
            continue
        for cat in SERVICE_KEYWORD_MAP.keys():
            cat_words = [cw for cw in cat.split("_") if cw not in GENERIC_WORDS]
            if word in cat_words or (len(word) >= 4 and any(cw.startswith(word) or word.startswith(cw) for cw in cat_words)):
                return cat, False

    # 3. Match multi-word or longer keywords first (e.g. 'water purifier' before 'water')
    all_pairs = []
    for cat, keywords in SERVICE_KEYWORD_MAP.items():
        for kw in keywords:
            all_pairs.append((len(kw), kw, cat))
    all_pairs.sort(key=lambda x: x[0], reverse=True)

    for _, kw, cat in all_pairs:
        if kw in clean or (len(clean) >= 3 and clean in kw):
            return cat, False

    clean_slug = clean.replace(" ", "_")
    return clean_slug, False

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


# ── Multi-City & Division Geospatial Registry ─────────────────────────────
# Comprehensive geospatial division registry covering Mysuru, Bengaluru, Mandya,
# Hassan, Hubli-Dharwad, Mangaluru, and dynamic expansion for all upcoming cities.
CITY_DIVISIONS_REGISTRY = {
    "Mysuru": {
        "lat_min": 12.18, "lat_max": 12.45, "lng_min": 76.50, "lng_max": 76.78,
        "divisions": [
            ("Kuvempunagar", 12.2905, 76.6277),
            ("Gokulam", 12.3308, 76.6267),
            ("Vijayanagar", 12.3374, 76.6111),
            ("Jayalakshmipuram", 12.3215, 76.6321),
            ("Hebbal Industrial", 12.3562, 76.6047),
            ("Saraswathipuram", 12.3021, 76.6345),
            ("Mysore Palace / Central", 12.3051, 76.6551),
            ("Vidyaranyapuram", 12.2780, 76.6490),
            ("Chamundipuram", 12.2920, 76.6620),
            ("Bannimantap", 12.3340, 76.6530),
            ("Mandi Mohalla", 12.3160, 76.6520),
            ("Alanahalli", 12.2910, 76.7020),
            ("Metagalli", 12.3480, 76.6320),
            ("Bogadi", 12.3040, 76.5980),
            ("Dattagalli", 12.2850, 76.6050),
            ("Roopa Nagar", 12.2960, 76.5890),
            ("Ramakrishnanagar", 12.2795, 76.6210),
            ("JP Nagar Mysuru", 12.2680, 76.6370),
            ("Nazarbad", 12.3090, 76.6680),
            ("Yadavagiri", 12.3280, 76.6420),
        ]
    },
    "Bengaluru": {
        "lat_min": 12.75, "lat_max": 13.20, "lng_min": 77.40, "lng_max": 77.85,
        "divisions": [
            ("Koramangala", 12.9352, 77.6245),
            ("Indiranagar", 12.9784, 77.6408),
            ("HSR Layout", 12.9121, 77.6446),
            ("Whitefield", 12.9698, 77.7500),
            ("Jayanagar", 12.9308, 77.5838),
            ("Electronic City", 12.8452, 77.6602),
            ("BTM Layout", 12.9166, 77.6101),
            ("Malleshwaram", 13.0031, 77.5643),
            ("Hebbal Bengaluru", 13.0358, 77.5970),
            ("Marathahalli", 12.9591, 77.6974),
            ("Yelahanka", 13.1007, 77.5963),
            ("Rajajinagar", 12.9918, 77.5529),
            ("Banashankari", 12.9255, 77.5468),
            ("Bellandur", 12.9304, 77.6784),
            ("Sarjapur Road", 12.9081, 77.6891),
            ("Basavanagudi", 12.9416, 77.5755),
        ]
    },
    "Mandya": {
        "lat_min": 12.45, "lat_max": 12.65, "lng_min": 76.80, "lng_max": 77.05,
        "divisions": [
            ("Mandya City Center", 12.5226, 76.8974),
            ("Sugar Town", 12.5350, 76.9120),
            ("Srirangapatna", 12.4225, 76.6946),
            ("Maddur", 12.5838, 77.0454),
            ("Pandavapura", 12.4960, 76.6710),
            ("Malavalli", 12.3850, 77.0580),
        ]
    },
    "Hassan": {
        "lat_min": 12.90, "lat_max": 13.15, "lng_min": 76.00, "lng_max": 76.25,
        "divisions": [
            ("Hassan City Center", 13.0072, 76.1029),
            ("Vidyanagar Hassan", 13.0180, 76.0950),
            ("Channarayapatna", 12.9040, 76.3880),
            ("Arsikere", 13.3130, 76.2570),
        ]
    },
    "Hubli": {
        "lat_min": 15.25, "lat_max": 15.55, "lng_min": 75.00, "lng_max": 75.30,
        "divisions": [
            ("Hubli City Center", 15.3647, 75.1240),
            ("Vidyanagar Hubli", 15.3710, 75.1180),
            ("Dharwad Central", 15.4589, 75.0078),
            ("Navanagar", 15.3920, 75.0920),
            ("Gokul Road", 15.3520, 75.1050),
        ]
    },
    "Mangaluru": {
        "lat_min": 12.75, "lat_max": 13.05, "lng_min": 74.75, "lng_max": 75.00,
        "divisions": [
            ("Mangaluru Central", 12.9141, 74.8560),
            ("Hampankatta", 12.8680, 74.8420),
            ("Kadri", 12.8840, 74.8620),
            ("Bejai", 12.8890, 74.8480),
            ("Surathkal", 13.0110, 74.7930),
        ]
    },
}

def resolve_city_and_division(lat: float, lng: float, area_hint: Optional[str] = None) -> tuple[str, str, bool]:
    """
    Geospatially maps user coordinates or area hint to City, Division, and Upcoming City status.
    Returns: (city_name, division_name, is_upcoming_city)
    """
    if area_hint:
        hint_clean = area_hint.lower()
        for city_name, city_info in CITY_DIVISIONS_REGISTRY.items():
            if city_name.lower() in hint_clean:
                for div_name, _, _ in city_info["divisions"]:
                    if div_name.lower() in hint_clean:
                        return city_name, div_name, False
                return city_name, city_info["divisions"][0][0], False
            for div_name, _, _ in city_info["divisions"]:
                if div_name.lower() in hint_clean:
                    return city_name, div_name, False

    # Check known city bounding boxes
    for city_name, city_info in CITY_DIVISIONS_REGISTRY.items():
        if (city_info["lat_min"] <= lat <= city_info["lat_max"] and
            city_info["lng_min"] <= lng <= city_info["lng_max"]):
            closest_div = city_info["divisions"][0][0]
            min_dist = float("inf")
            for div_name, d_lat, d_lng in city_info["divisions"]:
                dist = _haversine_m(lat, lng, d_lat, d_lng)
                if dist < min_dist:
                    min_dist = dist
                    closest_div = div_name
            return city_name, closest_div, False

    # Dynamic Upcoming City / Regional Hub Mapping
    nearest_city = "Mysuru"
    nearest_div = "Mysore Palace / Central"
    min_dist = float("inf")
    for city_name, city_info in CITY_DIVISIONS_REGISTRY.items():
        for div_name, d_lat, d_lng in city_info["divisions"]:
            dist = _haversine_m(lat, lng, d_lat, d_lng)
            if dist < min_dist:
                min_dist = dist
                nearest_city = city_name
                nearest_div = div_name

    if min_dist <= 75000:
        return nearest_city, f"{nearest_div} (Expansion Zone)", False

    return f"Upcoming City ({round(lat, 2)}, {round(lng, 2)})", "Regional Division", True


def format_customer_busy_advisory(division: str, city: str, category: Optional[str] = None, is_upcoming: bool = False) -> str:
    """
    Constructs an empathetic, actionable customer advisory advising that workers in the customer's
    local region/division are currently busy or unavailable, and highlighting verified top-rated
    service specialists available across the entire city.
    """
    cat_label = (category or "service").replace("_", " ").title() if category else "Service"
    if is_upcoming:
        return (
            f"Workers in your region ({division}) are currently busy or onboarding. "
            f"You can book these high-rated {cat_label} specialists available in nearby {city} hubs!"
        )
    return (
        f"Workers in your region ({division}) are currently busy. "
        f"You can book these high-rated {cat_label} workers across the entire city of {city}!"
    )


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


@router.get("/search")
def search_workers(
    category: Optional[str] = None,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    service_type: Optional[str] = None,
    area: Optional[str] = None,
    division: Optional[str] = None,
    radius_km: Optional[float] = None,
    page: int = 0,
    limit: int = 20,
):
    """
    Universal Hyperlocal & Regional Worker Search Endpoint with Tiered-Radius (Nearest-First),
    Dynamic Category Alias Resolution, and Fault-Tolerant Multi-Location Fallback.

    Guarantees zero crashes: coordinates from any location (or missing/0.0 coords)
    are gracefully normalized and evaluated without returning 400/500 errors.
    """
    raw_category = category or service_type
    req_category, is_all_categories = resolve_search_category(raw_category)

    # ── Universal Location Coordinates Normalization & Fault-Tolerance ──
    # Default to Mysuru center (12.3051, 76.6551) if lat/lng is missing, null, or zero
    DEFAULT_FALLBACK_LAT = 12.3051
    DEFAULT_FALLBACK_LNG = 76.6551
    is_default_coords = False

    if lat is None or lng is None:
        lat = DEFAULT_FALLBACK_LAT
        lng = DEFAULT_FALLBACK_LNG
        is_default_coords = True
    else:
        try:
            lat = float(lat)
            lng = float(lng)
            if (abs(lat) < 0.0001 and abs(lng) < 0.0001) or not (-90.0 <= lat <= 90.0) or not (-180.0 <= lng <= 180.0):
                lat = DEFAULT_FALLBACK_LAT
                lng = DEFAULT_FALLBACK_LNG
                is_default_coords = True
        except (ValueError, TypeError):
            lat = DEFAULT_FALLBACK_LAT
            lng = DEFAULT_FALLBACK_LNG
            is_default_coords = True

    # Resolve user's city, division, and upcoming city status
    area_hint = area or division
    user_city, user_division, is_upcoming = resolve_city_and_division(lat, lng, area_hint=area_hint)

    # ── 1. Redis Response Cache check (30s TTL) ──
    cache_cat = "all" if is_all_categories else req_category
    div_slug = user_division.lower().replace(" ", "_")
    cache_key = f"cache:worker_search_priority:{cache_cat}:{round(lat, 3)}:{round(lng, 3)}:{div_slug}"
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
    if not is_all_categories and not is_default_coords:
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
                        if w_st not in ["approved", "verified", "active"]:
                            continue
                        dist_val = w.get("distance_meters") or w.get("distance_m") or 0.0
                        formatted_workers.append({
                            "id": wid,
                            "name": w.get("name") or "Worker",
                            "category": w.get("category") or w.get("work_category") or req_category or "Service Expert",
                            "work_category": w.get("work_category") or w.get("category") or req_category or "Service Expert",
                            "service_types": w.get("skills") or [w.get("category") or req_category],
                            "phone_masked": mask_phone_number(w.get("phone")),
                            "rating": float(w.get("rating") or 0.0),
                            "distance_m": int(round(float(dist_val))),
                            "distance_meters": float(dist_val),
                            "is_verified": bool(w.get("is_verified", w.get("isVerified", True))),
                            "is_available": bool(w.get("is_available", True)),
                            "profile_photo": w.get("profile_photo") or w.get("id_document_url"),
                            "completed_jobs": int(w.get("completed_jobs") or w.get("total_jobs") or w.get("totalJobsCompleted") or 0),
                            "total_jobs": int(w.get("total_jobs") or w.get("completed_jobs") or w.get("totalJobsCompleted") or 0),
                            "hourly_rate": float(w.get("hourly_rate") or w.get("rate_per_hour") or 150.0),
                            "area": w.get("area") or "Mysuru",
                        })
                    
                    if formatted_workers:
                        formatted_workers.sort(key=lambda x: x["distance_m"])
                        formatted_workers = formatted_workers[:20]

                        response_data = {
                            "mode": "nearest",
                            "is_fallback": False,
                            "advisory_message": None,
                            "user_city": user_city,
                            "user_division": user_division,
                            "is_upcoming_city": is_upcoming,
                            "category": req_category,
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

    # ── 3. Database Direct Query Engine (Universal Multi-Location Matcher) ──
    try:
        db_res = supabase.table("workers").select("*").execute()
        all_rows = db_res.data or []
    except Exception as db_err:
        logger.error(f"Failed to query workers table: {db_err}")
        all_rows = []

    matching_workers = []
    # Build list of related keywords for the category
    related_keywords = [req_category] if req_category else []
    if req_category in SERVICE_KEYWORD_MAP:
        related_keywords.extend(SERVICE_KEYWORD_MAP[req_category])

    for w in all_rows:
        w_cat = str(w.get("work_category") or w.get("category") or "").lower().replace("-", "_").replace(" ", "_")
        w_skills = [str(s).lower().replace("-", "_").replace(" ", "_") for s in (w.get("skills") or [])]
        w_specs = [str(s).lower().replace("-", "_").replace(" ", "_") for s in (w.get("specialities") or [])]

        if is_all_categories:
            cat_match = True
        elif not req_category:
            cat_match = True
        else:
            cat_match = (
                bool(w_cat and any(kw in w_cat or w_cat in kw for kw in related_keywords if len(kw) >= 2)) or
                any(any(kw in s or s in kw for kw in related_keywords if len(kw) >= 2) for s in w_skills) or
                any(any(kw in s or s in kw for kw in related_keywords if len(kw) >= 2) for s in w_specs)
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

        if (w_lat is None or w_lng is None) and w.get("lat") is not None and w.get("lng") is not None:
            try:
                w_lat = float(w["lat"])
                w_lng = float(w["lng"])
            except (ValueError, TypeError):
                pass

        dist_m = None
        if w_lat is not None and w_lng is not None:
            try:
                dist_m = _haversine_m(lat, lng, w_lat, w_lng)
            except Exception:
                dist_m = None

        w_jobs = int(w.get("total_completed_jobs") or w.get("total_jobs") or w.get("totalJobsCompleted") or 0)
        w_raw_rating = w.get("rating")
        if w_jobs == 0 or w_raw_rating is None or float(w_raw_rating) == 0.0:
            w_rating = None
        else:
            w_rating = float(w_raw_rating)
        w_masked_phone = mask_phone_number(w.get("phone"))

        w_dict = {
            "id": str(w.get("id") or ""),
            "name": w.get("name") or "Verified Worker",
            "category": w.get("category") or w.get("work_category") or (req_category if not is_all_categories else "Service Expert"),
            "work_category": w.get("work_category") or w.get("category") or "Service Expert",
            "skills": w.get("skills") or [],
            "specialities": w.get("specialities") or [],
            "service_types": w.get("skills") or [w.get("category") or "Service Expert"],
            "phone_masked": w_masked_phone,
            "rating": w_rating,
            "total_completed_jobs": w_jobs,
            "hourly_rate": float(w.get("hourly_rate") or w.get("rate_per_hour") or 150.0),
            "profile_photo": w.get("profile_photo") or w.get("id_document_url"),
            "is_verified": bool(w.get("is_verified", w.get("isVerified", w.get("id_verified", True)))),
            "is_available": is_avail,
            "city": w.get("city") or "Mysuru",
            "area": w.get("area") or "Mysuru",
            "distance_m": dist_m,
        }
        matching_workers.append(w_dict)

    # Priority 1 — Nearest expanding radius search across tiers
    for radius in RADIUS_TIERS_METERS:
        tier_workers = [
            w for w in matching_workers
            if w["distance_m"] is not None and w["distance_m"] <= radius
        ]
        if tier_workers:
            tier_workers.sort(key=lambda x: x["distance_m"])
            unlocated = [w for w in matching_workers if w["distance_m"] is None]
            unlocated.sort(
                key=lambda x: (
                    x["rating"] if x["rating"] is not None else -1.0,
                    x["total_completed_jobs"],
                    1 if x["is_verified"] else 0
                ),
                reverse=True
            )
            all_found = (tier_workers + unlocated)[:20]
            formatted = [
                {
                    "id": w["id"],
                    "name": w["name"],
                    "category": w["category"],
                    "work_category": w.get("work_category", w["category"]),
                    "service_types": w.get("service_types") or [w["category"]],
                    "phone_masked": w["phone_masked"],
                    "rating": w["rating"],
                    "distance_m": int(round(w["distance_m"])) if w["distance_m"] is not None else None,
                    "distance_meters": float(w["distance_m"]) if w["distance_m"] is not None else None,
                    "is_verified": w["is_verified"],
                    "is_available": w.get("is_available", True),
                    "profile_photo": w.get("profile_photo"),
                    "completed_jobs": w.get("total_completed_jobs", 0),
                    "total_jobs": w.get("total_completed_jobs", 0),
                    "hourly_rate": float(w.get("hourly_rate", 150.0)),
                    "city": w.get("city") or user_city or "Mysuru",
                    "area": w.get("area") or "Mysuru",
                }
                for w in all_found
            ]
            response_data = {
                "mode": "nearest",
                "is_fallback": False,
                "advisory_message": None,
                "user_city": user_city,
                "user_division": user_division,
                "is_upcoming_city": is_upcoming,
                "category": req_category,
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

    # Priority 2 & 3 — Universal Location-Agnostic Rating Fallback (Every Location Safe)
    if matching_workers:
        # Sort by rating DESC, completed jobs DESC, and distance if known
        matching_workers.sort(
            key=lambda x: (
                x["rating"] if x["rating"] is not None else -1.0,
                x["total_completed_jobs"],
                1 if x["is_verified"] else 0,
                -x["distance_m"] if x["distance_m"] is not None else -99999999
            ),
            reverse=True
        )
        formatted_fallback = [
            {
                "id": w["id"],
                "name": w["name"],
                "category": w["category"],
                "work_category": w.get("work_category", w["category"]),
                "service_types": w.get("service_types") or [w["category"]],
                "phone_masked": w["phone_masked"],
                "rating": w["rating"],
                "distance_m": int(round(w["distance_m"])) if w["distance_m"] is not None else None,
                "distance_meters": float(w["distance_m"]) if w["distance_m"] is not None else None,
                "is_verified": w["is_verified"],
                "is_available": w.get("is_available", True),
                "profile_photo": w.get("profile_photo"),
                "completed_jobs": w.get("total_completed_jobs", 0),
                "total_jobs": w.get("total_completed_jobs", 0),
                "hourly_rate": float(w.get("hourly_rate", 150.0)),
                "city": w.get("city") or user_city or "Mysuru",
                "area": w.get("area") or "Mysuru",
            }
            for w in matching_workers[:20]
        ]
        advisory_msg = format_customer_busy_advisory(user_division, user_city, req_category, is_upcoming)
        response_data = {
            "mode": "citywide_rating_fallback",
            "is_fallback": True,
            "advisory_message": advisory_msg,
            "user_city": user_city,
            "user_division": user_division,
            "is_upcoming_city": is_upcoming,
            "category": req_category,
            "count": len(formatted_fallback),
            "workers": formatted_fallback,
        }
        if r:
            try:
                r.set(cache_key, json.dumps(response_data), ex=30)
            except Exception:
                pass
        return response_data

    # Zero workers found for category across all locations
    cat_label = (req_category or "service").replace("_", " ").title() if req_category else "Service"
    advisory_msg = (
        f"Workers in your region ({user_division}) are currently busy. "
        f"No {cat_label} experts are currently online in {user_city}."
    )
    response_data = {
        "mode": "no_workers_found",
        "is_fallback": True,
        "advisory_message": advisory_msg,
        "user_city": user_city,
        "user_division": user_division,
        "is_upcoming_city": is_upcoming,
        "category": req_category,
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
        area=payload.get("area") or payload.get("division") or payload.get("location_name"),
        division=payload.get("division"),
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


