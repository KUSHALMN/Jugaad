import shared.firebase_init  # noqa: F401 — must be first
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from shared.auth import verify_firebase_token
from shared.database import supabase
from shared.logging import log
from datetime import datetime, timezone

app = FastAPI(title="User Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
def health():
    return {"status": "ok", "service": "user_service"}


@app.get("/users/me")
def get_profile(uid: str = Depends(verify_firebase_token)):
    result = supabase.table("users").select("*").eq("firebase_uid", uid).single().execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")
    return result.data


@app.put("/users/me")
def update_profile(profile: dict, uid: str = Depends(verify_firebase_token)):
    profile["updated_at"] = datetime.now(timezone.utc).isoformat()
    supabase.table("users").update(profile).eq("firebase_uid", uid).execute()
    return {"status": "success", "message": "Profile updated"}


class FCMTokenPayload(BaseModel):
    token: str


@app.post("/v1/users/me/fcm-token")
def update_my_fcm_token(body: FCMTokenPayload, uid: str = Depends(verify_firebase_token)):
    """Update FCM token for the authenticated user. Called from Flutter FCMTokenManager."""
    try:
        supabase.table("users").update({
            "fcm_token": body.token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("firebase_uid", uid).execute()

        log("user_service", "update_fcm_token", "success",
            uid=uid, token_prefix=body.token[:20] if body.token else "")

        return {"status": "success", "message": "FCM token updated"}
    except Exception as e:
        log("user_service", "update_fcm_token", "error",
            severity="ERROR", uid=uid, error=str(e))
        raise HTTPException(500, "Failed to update FCM token")


@app.post("/v1/users/sync")
def sync_user(payload: dict, uid: str = Depends(verify_firebase_token)):
    """Creates or updates a user profile bypassing RLS. Called after Firebase login/signup."""
    result = supabase.table("users").select("id").eq("firebase_uid", uid).execute()
    
    if not result.data:
        # New user
        supabase.table("users").insert({
            "id": uid,
            "firebase_uid": uid,
            "email": payload.get("email") or None,
            "name": payload.get("name", ""),
            "phone": payload.get("phone") or None,
            "role": "employer"
        }).execute()
        log("user_service", "sync_user", "created", uid=uid)
    else:
        # Existing user, optionally update basic info
        update_data = {}
        if payload.get("email"): update_data["email"] = payload["email"]
        if payload.get("name"): update_data["name"] = payload["name"]
        if payload.get("phone"): update_data["phone"] = payload["phone"]
        if update_data:
            supabase.table("users").update(update_data).eq("firebase_uid", uid).execute()
        log("user_service", "sync_user", "updated", uid=uid)
        
    return {"status": "success", "message": "User synced"}


@app.post("/v1/users/{user_id}/fcm-token")
def user_fcm_token(user_id: str, payload: dict, uid: str = Depends(verify_firebase_token)):
    if uid != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    token = payload.get("token")
    if token:
        supabase.table("users").update({
            "fcm_token": token,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("firebase_uid", user_id).execute()
        log("user_service", "user_fcm_token", "success",
            uid=user_id, token_prefix=token[:20] if token else "")
    return {"status": "success"}

