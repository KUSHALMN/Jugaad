import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared.models import ReviewRequest

app = FastAPI(title="Review Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
def health():
    return {"status": "ok", "service": "review_service"}


@app.post("/reviews")
def submit_review(review: ReviewRequest, uid: str = Depends(verify_firebase_token)):
    """
    Submit a review for a worker.
    Uses Supabase RPC for atomic review + rating update.
    BEFORE: Firestore transaction with subcollection
    AFTER:  Supabase RPC (submit_review_atomic) — flat reviews table
    """
    # Look up internal UUID
    user_result = supabase.table("users").select("id").eq("firebase_uid", uid).single().execute()
    reviewer_id = user_result.data["id"]

    # Use atomic RPC
    supabase.rpc("submit_review_atomic", {
        "p_job_id": review.jobId,
        "p_reviewer_id": str(reviewer_id),
        "p_reviewee_id": review.workerId,
        "p_rating": review.rating,
        "p_comment": review.comment,
    }).execute()

    return {"status": "success", "message": "Review submitted and aggregate updated"}
