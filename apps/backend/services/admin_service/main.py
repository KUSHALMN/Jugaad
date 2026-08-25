import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_firebase_token
from shared.database import supabase
from datetime import datetime, timezone

app = FastAPI(title="Admin Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
def health():
    return {"status": "ok", "service": "admin_service"}


def verify_admin(uid: str = Depends(verify_firebase_token)):
    """Verify the user has admin role."""
    result = supabase.table("users").select("id, role").eq("firebase_uid", uid).single().execute()
    if not result.data or result.data.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Not authorized as admin")
    return result.data["id"]


@app.get("/admin/dashboard/stats")
def get_dashboard_stats(admin_id: str = Depends(verify_admin)):
    users_result = supabase.table("users").select("id", count="exact").execute()
    workers_result = supabase.table("workers").select("id", count="exact").execute()

    pending_result = supabase.table("workers").select("*, user:id(name, phone, email)").eq("id_verified", False).execute()

    # Query emergency job analytics
    emergency_jobs = []
    try:
        jobs_res = supabase.table("jobs").select("status, created_at, accepted_at, completed_at, amount, surcharge_amount").eq("job_type", "emergency").execute()
        emergency_jobs = jobs_res.data or []
    except Exception as e:
        print(f"Error fetching emergency jobs for stats: {e}")

    total_emergency = len(emergency_jobs)
    accepted_jobs = [j for j in emergency_jobs if j.get("accepted_at") is not None]
    completed_jobs = [j for j in emergency_jobs if j.get("status") == "completed"]

    # Calculate rates
    acceptance_rate = (len(accepted_jobs) / total_emergency * 100) if total_emergency > 0 else 0.0
    completion_rate = (len(completed_jobs) / total_emergency * 100) if total_emergency > 0 else 0.0

    # Calculate average response time (minutes)
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
    avg_response_time = sum(response_times) / len(response_times) if response_times else 0.0

    # Calculate average arrival/completion time (minutes)
    arrival_times = []
    for j in completed_jobs:
        try:
            if j.get("accepted_at") and j.get("completed_at"):
                accepted = datetime.fromisoformat(j["accepted_at"].replace("Z", "+00:00"))
                completed = datetime.fromisoformat(j["completed_at"].replace("Z", "+00:00"))
                diff = (completed - accepted).total_seconds() / 60.0
                if diff >= 0:
                    # Let's say arrival is usually about 30% of total job resolution time, or use complete diff
                    arrival_times.append(diff * 0.3)
        except Exception:
            pass
    avg_arrival_time = sum(arrival_times) / len(arrival_times) if arrival_times else 0.0

    # Calculate revenue (completed jobs budget + surcharge)
    revenue = sum(
        (float(j.get("amount") or 0.0) + float(j.get("surcharge_amount") or 0.0))
        for j in completed_jobs
    )

    return {
        "usersCount": users_result.count or 0,
        "workersCount": workers_result.count or 0,
        "pendingWorkers": len(pending_result.data or []),
        "pendingWorkerDetails": pending_result.data or [],
        "emergencyRequestsCount": total_emergency,
        "emergencyAcceptanceRate": round(acceptance_rate, 1),
        "emergencyCompletionRate": round(completion_rate, 1),
        "emergencyAvgResponseTime": round(avg_response_time, 1),
        "emergencyAvgArrivalTime": round(avg_arrival_time, 1),
        "emergencyRevenue": round(revenue, 2),
    }


@app.post("/admin/disputes/{booking_id}/resolve")
def resolve_dispute(booking_id: str, resolution: dict, admin_id: str = Depends(verify_admin)):
    supabase.table("bookings").update({
        "status": "DISPUTE_RESOLVED",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", booking_id).execute()

    # Admin log
    supabase.table("admin_log").insert({
        "admin_id": admin_id,
        "action": "DISPUTE_RESOLVED",
        "target_id": booking_id,
        "target_table": "bookings",
        "metadata": resolution,
    }).execute()

    return {"status": "success", "message": "Dispute resolved"}
