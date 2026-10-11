from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from shared.auth import verify_firebase_token
from services.dispatch_service import dispatch_service

from shared.database import supabase

router = APIRouter()

class DispatchResponse(BaseModel):
    job_id: str
    worker_id: str
    response: str  # "ACCEPT" | "REJECT"

@router.post("/respond")
async def respond_to_dispatch(body: DispatchResponse, uid: str = Depends(verify_firebase_token)):
    # 1. Authorize: verify caller matches worker_id
    user_res = supabase.table("users").select("id, firebase_uid").or_(f"firebase_uid.eq.{uid},id.eq.{uid}").maybe_single().execute()
    caller_internal_id = (user_res.data or {}).get("id")
    caller_fb_uid = (user_res.data or {}).get("firebase_uid")

    is_authorized = (
        body.worker_id == uid
        or (caller_internal_id and str(caller_internal_id) == str(body.worker_id))
        or (caller_fb_uid and str(caller_fb_uid) == str(body.worker_id))
    )

    if not is_authorized:
        raise HTTPException(
            status_code=403,
            detail="Forbidden: Cannot accept or reject jobs on behalf of another worker"
        )

    # 2. Forward to dispatch service with verified internal ID
    assigned_id = caller_internal_id or body.worker_id
    success = await dispatch_service.handle_worker_response(
        body.job_id,
        str(assigned_id),
        body.response.upper()
    )

    if body.response.upper() == "ACCEPT" and not success:
        raise HTTPException(status_code=409, detail="Job has already been accepted or is no longer available")

    return {"status": "ok", "response": body.response.upper()}
