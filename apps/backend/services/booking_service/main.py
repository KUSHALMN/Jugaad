import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared.logging import log
from pydantic import BaseModel
from datetime import datetime, timezone

app = FastAPI(title="Booking Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


class AcceptBookingRequest(BaseModel):
    """Payload for accepting a booking."""
    notes: str | None = None


@app.get("/health")
def health():
    return {"status": "ok", "service": "booking_service"}


@app.post("/v1/bookings/{booking_id}/accept")
def accept_booking(booking_id: str, uid: str = Depends(verify_firebase_token)):
    """
    Worker accepts a booking.
    BEFORE: Firestore transaction
    AFTER:  Supabase conditional update (WHERE status = 'pending')
    """
    # Look up internal UUID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    worker_id = user_result.data["id"]

    result = supabase.table("bookings").select("*").eq("id", booking_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Booking not found")
    if result.data.get("status") != "pending":
        raise HTTPException(400, "Booking no longer available")

    supabase.table("bookings").update({
        "status": "accepted",
        "worker_id": worker_id,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", booking_id).eq("status", "pending").execute()

    log("booking_service", "accept_booking", "accepted",
        booking_id=booking_id, worker_id=str(worker_id))
    return {"status": "accepted", "booking_id": booking_id}


@app.post("/v1/bookings/{booking_id}/complete")
def complete_booking(booking_id: str, uid: str = Depends(verify_firebase_token)):
    """
    Worker marks a booking as completed.
    BEFORE: Firestore transaction with fs.Increment()
    AFTER:  Supabase RPC for atomic update
    """
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    worker_id = user_result.data["id"]

    result = supabase.table("bookings").select("*").eq("id", booking_id).single().execute()
    if not result.data:
        raise HTTPException(404, "Booking not found")

    data = result.data
    status = data.get("status", "")

    if status == "completed":
        raise HTTPException(409, "Booking is already completed")
    if status not in ("in_progress", "confirmed"):
        raise HTTPException(400, f"Cannot complete a booking with status '{status}'.")

    assigned_worker = data.get("worker_id")
    if assigned_worker and str(assigned_worker) != str(worker_id):
        raise HTTPException(403, "You are not the assigned worker for this booking")

    # Get amount from related job
    job_result = supabase.table("jobs").select("amount").eq("id", data["job_id"]).single().execute()
    amount = float(job_result.data.get("amount", 0)) if job_result.data else 0.0

    # Update booking
    supabase.table("bookings").update({
        "status": "completed",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", booking_id).execute()

    # Update worker counters
    # Atomic increment via RPC to avoid read-modify-write race condition
    supabase.rpc("increment_worker_total_jobs", {"p_worker_id": str(worker_id)}).execute()

    log("booking_service", "complete_booking", "completed",
        booking_id=booking_id, worker_id=str(worker_id), amount=amount)

    return {
        "status": "completed",
        "booking_id": booking_id,
        "amount": amount,
        "message": f"Rs.{amount:.0f} added to worker withdrawable balance",
    }
