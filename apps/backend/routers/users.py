from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from shared.auth import verify_firebase_token
from shared.database import supabase
from datetime import datetime, timezone
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

class FCMTokenPayload(BaseModel):
    token: str

@router.get("/me")
def get_profile(uid: str = Depends(verify_firebase_token)):
    result = supabase.table("users").select("*").eq("firebase_uid", uid).single().execute()
    if not result.data:
        raise HTTPException(status_code=444, detail="User not found")
    return result.data

@router.put("/me")
def update_profile(profile: dict, uid: str = Depends(verify_firebase_token)):
    profile["updated_at"] = datetime.now(timezone.utc).isoformat()
    supabase.table("users").update(profile).eq("firebase_uid", uid).execute()
    return {"status": "success", "message": "Profile updated"}

@router.post("/me/fcm-token")
@router.patch("/me/fcm-token")
def update_my_fcm_token(body: FCMTokenPayload, uid: str = Depends(verify_firebase_token)):
    try:
        supabase.table("users").update({
            "fcm_token": body.token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("firebase_uid", uid).execute()
        return {"status": "success", "message": "FCM token updated"}
    except Exception as e:
        logger.error(f"Failed to update FCM token: {e}")
        raise HTTPException(500, "Failed to update FCM token")

@router.post("/sync")
def sync_user(payload: dict, uid: str = Depends(verify_firebase_token)):
    result = supabase.table("users").select("id").eq("firebase_uid", uid).execute()
    
    if not result.data:
        # New user
        supabase.table("users").insert({
            "id": uid,
            "firebase_uid": uid,
            "email": payload.get("email") or None,
            "name": payload.get("name", ""),
            "phone": payload.get("phone") or None,
            "role": payload.get("role", "employer")
        }).execute()
        logger.info(f"User synced (created): {uid}")
    else:
        # Existing user
        update_data = {}
        if payload.get("email"): update_data["email"] = payload["email"]
        if payload.get("name"): update_data["name"] = payload["name"]
        if payload.get("phone"): update_data["phone"] = payload["phone"]
        if update_data:
            supabase.table("users").update(update_data).eq("firebase_uid", uid).execute()
        logger.info(f"User synced (updated): {uid}")
        
    return {"status": "success", "message": "User synced"}

@router.post("/{user_id}/fcm-token")
def user_fcm_token(user_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    token = payload.get("token")
    if token:
        supabase.table("users").update({
            "fcm_token": token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("firebase_uid", user_id).execute()
    return {"status": "success"}
