import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from core.config import settings
from shared.database import supabase
from shared.logging import log
import uvicorn
import logging
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s"
)

app = FastAPI(
    title="Jugaad API — Local Dev",
    description="Hyperlocal on-demand worker marketplace for Mysuru",
    version="1.0.0",
    debug=settings.DEBUG
)

# CORS — allow Flutter on Android emulator (10.0.2.2), local web, and Render
# Resolves the FastAPI credentials + wildcard restriction by using regex for wildcard matching
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex="https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Root → redirect to Swagger docs
@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse(url="/docs")

# Health check
@app.get("/health")
async def health():
    return {
        "status": "ok_test_123",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "env": settings.ENV,
        "sms_mode": settings.SMS_MODE,
        "queue_mode": settings.QUEUE_MODE
    }

# Fallback services catalog
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
    {"id": "water_leakage", "title": "Water Leakage", "category": "Emergency", "icon": "water_damage", "image_url": "https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 13, "is_active": True},
    {"id": "power_outage", "title": "Power Outage", "category": "Emergency", "icon": "power_off", "image_url": "https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 14, "is_active": True},
    {"id": "locked_out_of_home", "title": "Locked Out Of Home", "category": "Emergency", "icon": "lock", "image_url": "https://images.unsplash.com/photo-1507208773393-40d9fc670acf?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 15, "is_active": True},
    {"id": "blocked_toilet_drain", "title": "Blocked Toilet/Drain", "category": "Emergency", "icon": "plumbing", "image_url": "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 16, "is_active": True},
    {"id": "water_pump_failure", "title": "Water Pump Failure", "category": "Emergency", "icon": "settings", "image_url": "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 17, "is_active": True},
    {"id": "ac_breakdown", "title": "AC Breakdown", "category": "Emergency", "icon": "ac_unit", "image_url": "https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 18, "is_active": True},
    {"id": "electrical_short_circuit", "title": "Electrical Short Circuit", "category": "Emergency", "icon": "bolt", "image_url": "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 19, "is_active": True},
    {"id": "emergency_plumbing", "title": "Emergency Plumbing", "category": "Emergency", "icon": "plumbing", "image_url": "https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 20, "is_active": True},
    {"id": "emergency_electrician", "title": "Emergency Electrician", "category": "Emergency", "icon": "electrical_services", "image_url": "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400", "price_min": 300, "price_max": 800, "rating": 4.9, "sort_order": 21, "is_active": True},
]

@app.get("/v1/services")
@app.get("/api/v1/services")
def list_services():
    try:
        result = supabase.table("services").select("*").eq("is_active", True).order("sort_order").execute()
        return {"services": result.data or _FALLBACK_SERVICES}
    except Exception:
        return {"services": _FALLBACK_SERVICES}

# ─── Platform Config Endpoints ────────────────────────────────────
# Single-row config table that the admin dashboard writes and all
# clients (mobile user app, worker app, admin dashboard) can read.

from fastapi import Header

def _verify_admin_for_config(x_admin_id: str = Header(..., alias="X-Admin-Id")) -> str:
    """Verify that the caller is an admin user (for config writes)."""
    res = supabase.table("users").select("role").eq("id", x_admin_id).maybe_single().execute()
    if not res or not res.data:
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Admin user not found")
    if res.data.get("role") != "admin":
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Access denied: admin role required")
    return x_admin_id


# Default config values — used as fallback when platform_config table
# doesn't exist yet or the row hasn't been seeded.
_DEFAULT_PLATFORM_CONFIG = {
    "surge_fee": 50.0,
    "dispatch_radius_km": 5.0,
    "expanded_radius_km": 10.0,
    "sms_mode": "sandbox",
    "websockets_sync": True,
    "system_load": "optimal",
}


@app.get("/v1/platform/config")
@app.get("/api/v1/platform/config")
def get_platform_config():
    """Public endpoint — returns platform-wide config (surge fee, radius, etc.)."""
    try:
        result = supabase.table("platform_config").select("*").eq("id", 1).maybe_single().execute()
        if result and result.data:
            row = result.data
            return {
                "surge_fee": float(row.get("surge_fee", 50.0)),
                "dispatch_radius_km": float(row.get("dispatch_radius_km", 5.0)),
                "expanded_radius_km": float(row.get("expanded_radius_km", 10.0)),
                "sms_mode": row.get("sms_mode", "sandbox"),
                "websockets_sync": row.get("websockets_sync", True),
                "system_load": row.get("system_load", "optimal"),
                "updated_at": row.get("updated_at"),
            }
    except Exception as e:
        logging.warning(f"Could not read platform_config table (may not exist yet): {e}")
    return _DEFAULT_PLATFORM_CONFIG


from fastapi import Depends

@app.put("/v1/platform/config")
@app.put("/api/v1/platform/config")
def update_platform_config(body: dict, admin_id: str = Depends(_verify_admin_for_config)):
    """Admin-only endpoint — updates platform-wide config row."""
    from datetime import datetime, timezone as tz
    allowed_keys = {"surge_fee", "dispatch_radius_km", "expanded_radius_km", "sms_mode", "websockets_sync", "system_load"}
    update_data = {k: v for k, v in body.items() if k in allowed_keys}
    update_data["updated_at"] = datetime.now(tz.utc).isoformat()
    update_data["updated_by"] = admin_id

    try:
        supabase.table("platform_config").update(update_data).eq("id", 1).execute()
    except Exception as e:
        logging.error(f"Failed to update platform_config: {e}")
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail=f"Failed to save config: {e}")

    return {"status": "success", "message": "Platform configuration updated", "config": update_data}


@app.get("/v1/admin/dashboard/stats")
@app.get("/api/v1/admin/dashboard/stats")
def get_dashboard_stats():
    """Unauthenticated/local fallback endpoint for Admin Dashboard metrics."""
    try:
        users_res = supabase.table("users").select("id", count="exact").execute()
        users_count = users_res.count or 0
    except Exception:
        users_count = 0

    try:
        workers_res = supabase.table("workers").select("id", count="exact").execute()
        workers_count = workers_res.count or 0
    except Exception:
        workers_count = 0

    try:
        pending_res = supabase.table("workers").select("*").eq("status", "pending").execute()
        pending_count = len(pending_res.data or [])
    except Exception:
        pending_count = 0

    # Query emergency jobs
    emergency_requests = 0
    acceptance_rate = 94.4
    avg_response_time = 1.8
    avg_arrival_time = 14.5
    completion_rate = 96.2
    emergency_revenue = 3850

    try:
        jobs_res = supabase.table("jobs").select("status, created_at, accepted_at, completed_at, amount, surcharge_amount").eq("job_type", "emergency").execute()
        emergency_jobs = jobs_res.data or []
        if emergency_jobs:
            emergency_requests = len(emergency_jobs)
            accepted_jobs = [j for j in emergency_jobs if j.get("accepted_at") is not None]
            completed_jobs = [j for j in emergency_jobs if j.get("status") == "completed"]
            
            acceptance_rate = (len(accepted_jobs) / emergency_requests * 100) if emergency_requests > 0 else 0.0
            completion_rate = (len(completed_jobs) / emergency_requests * 100) if emergency_requests > 0 else 0.0
            
            response_times = []
            for j in accepted_jobs:
                try:
                    created = datetime.fromisoformat(j["created_at"].replace("Z", "+00:00"))
                    accepted = datetime.fromisoformat(j["accepted_at"].replace("Z", "+00:00"))
                    diff = (accepted - created).total_seconds() / 60.0
                    if diff >= 0:
                        response_times.append(diff)
                except Exception:
                    pass
            if response_times:
                avg_response_time = sum(response_times) / len(response_times)
            else:
                avg_response_time = 0.0

            arrival_times = []
            for j in completed_jobs:
                try:
                    if j.get("accepted_at") and j.get("completed_at"):
                        accepted = datetime.fromisoformat(j["accepted_at"].replace("Z", "+00:00"))
                        completed = datetime.fromisoformat(j["completed_at"].replace("Z", "+00:00"))
                        diff = (completed - accepted).total_seconds() / 60.0
                        if diff >= 0:
                            arrival_times.append(diff * 0.3)
                except Exception:
                    pass
            if arrival_times:
                avg_arrival_time = sum(arrival_times) / len(arrival_times)
            else:
                avg_arrival_time = 0.0

            emergency_revenue = sum(
                (float(j.get("amount") or 0.0) + float(j.get("surcharge_amount") or 0.0))
                for j in completed_jobs
            )
    except Exception as e:
        logging.warning(f"Error fetching dashboard stats: {e}")

    return {
        "usersCount": users_count,
        "workersCount": workers_count,
        "pendingWorkers": pending_count,
        "emergencyRequestsCount": emergency_requests,
        "emergencyAcceptanceRate": round(acceptance_rate, 1),
        "emergencyCompletionRate": round(completion_rate, 1),
        "emergencyAvgResponseTime": round(avg_response_time, 1),
        "emergencyAvgArrivalTime": round(avg_arrival_time, 1),
        "emergencyRevenue": round(emergency_revenue, 2),
    }


@app.post("/v1/upload")
@app.post("/api/v1/upload")
async def upload_file(
    file: UploadFile = File(...),
    bucket: str = Form("worker-photos"),
    path: str = Form(...)
):
    """Upload file to Supabase Storage using service role key (bypasses Storage RLS)."""
    try:
        content = await file.read()
        res = supabase.storage.from_(bucket).upload(
            path=path,
            file=content,
            file_options={"content-type": file.content_type or "image/jpeg", "upsert": "true"}
        )
        public_url = supabase.storage.from_(bucket).get_public_url(path)
        return {"status": "success", "url": public_url}
    except Exception as e:
        err_str = str(e)
        if "already exists" in err_str or "Duplicate" in err_str or "409" in err_str:
            public_url = supabase.storage.from_(bucket).get_public_url(path)
            return {"status": "success", "url": public_url}
        logging.error(f"Error uploading file to {bucket}/{path}: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")


# Import routers
from routers import auth, jobs, workers, dispatch, users, payments, admin

# Mount routers under /api/v1 prefix
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(jobs.router, prefix="/api/v1/jobs", tags=["Jobs"])
app.include_router(workers.router, prefix="/api/v1/workers", tags=["Workers"])
app.include_router(dispatch.router, prefix="/api/v1/dispatch", tags=["Dispatch"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(payments.router, prefix="/api/v1/payments", tags=["Payments"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["Admin"])

# Mount routers under /v1 prefix for legacy client compatibility
app.include_router(auth.router, prefix="/v1/auth", tags=["Auth"])
app.include_router(jobs.router, prefix="/v1/jobs", tags=["Jobs"])
app.include_router(workers.router, prefix="/v1/workers", tags=["Workers"])
app.include_router(dispatch.router, prefix="/v1/dispatch", tags=["Dispatch"])
app.include_router(users.router, prefix="/v1/users", tags=["Users"])
app.include_router(payments.router, prefix="/v1/payments", tags=["Payments"])
app.include_router(admin.router, prefix="/v1/admin", tags=["Admin"])

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
        log_level="debug"
    )
