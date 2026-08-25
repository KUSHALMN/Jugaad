from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from shared.auth import verify_firebase_token
from services.dispatch_service import dispatch_service

router = APIRouter()

class DispatchResponse(BaseModel):
    job_id: str
    worker_id: str
    response: str  # "ACCEPT" | "REJECT"

@router.post("/respond")
async def respond_to_dispatch(body: DispatchResponse, uid: str = Depends(verify_firebase_token)):
    await dispatch_service.handle_worker_response(
        body.job_id,
        body.worker_id,
        body.response
    )
    return {"status": "ok"}
