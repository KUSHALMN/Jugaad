from fastapi import APIRouter, Request, HTTPException, Depends
from pydantic import BaseModel
from shared.database import supabase
from shared.auth import verify_firebase_token
from services.sms_service import sms_service
import random
import time
from collections import defaultdict

router = APIRouter()

rate_limit_store = defaultdict(list)

def is_rate_limited(key: str, limit: int = 5, window: int = 60) -> bool:
    now = time.time()
    rate_limit_store[key] = [t for t in rate_limit_store[key] if now - t < window]
    if len(rate_limit_store[key]) >= limit:
        return True
    rate_limit_store[key].append(now)
    return False

class LoginResponse(BaseModel):
    message: str
    uid: str
    role: str

class SendOtpRequest(BaseModel):
    phone: str

class VerifyOtpRequest(BaseModel):
    phone: str
    otp: str

@router.post("/send-otp")
async def send_otp(request: Request, req: SendOtpRequest):
    client_ip = request.client.host if request.client else "unknown"
    if is_rate_limited(client_ip, limit=5, window=60) or is_rate_limited(req.phone, limit=5, window=60):
        raise HTTPException(status_code=429, detail="Too many OTP requests. Please try again later.")
    
    # Generate random 6-digit OTP
    otp = str(random.randint(100000, 999999))
    # Send via our local/real sms_service
    await sms_service.send_otp(req.phone, otp)
    return {"message": "OTP sent successfully", "otp": otp}

@router.post("/verify-otp")
async def verify_otp(req: VerifyOtpRequest):
    # Mock OTP verification for local testing
    return {"message": "OTP verified successfully", "token": "mock_firebase_token"}

@router.post("/login", response_model=LoginResponse)
def login(request: Request, uid: str = Depends(verify_firebase_token)):
    client_ip = request.client.host if request.client else "unknown"
    if is_rate_limited(client_ip, limit=5, window=60):
        raise HTTPException(status_code=429, detail="Too many login attempts.")

    result = supabase.table("users").select("id, role").eq("firebase_uid", uid).single().execute()

    if result.data:
        role = result.data.get("role", "employer")
    else:
        role = "new"

    return LoginResponse(message="Login successful", uid=uid, role=role)

@router.post("/register-user")
def register_user(profile: dict, uid: str = Depends(verify_firebase_token)):
    supabase.table("users").insert({
        "id": uid,
        "firebase_uid": uid,
        "phone": profile.get("phone") or None,
        "name": profile.get("name"),
        "email": profile.get("email"),
        "role": "employer",
    }).execute()
    return {"message": "User registered", "uid": uid, "role": "employer"}

@router.post("/register-worker")
def register_worker(profile: dict, uid: str = Depends(verify_firebase_token)):
    supabase.table("users").insert({
        "id": uid,
        "firebase_uid": uid,
        "phone": profile.get("phone") or None,
        "name": profile.get("name"),
        "email": profile.get("email"),
        "role": "worker",
    }).execute()

    worker_data = {
        "id": uid,
        "name": profile.get("name"),
        "phone": profile.get("phone") or None,
        "skills": profile.get("skills", []),
        "bio": profile.get("bio"),
        "area": profile.get("area", ""),
        "hourly_rate": profile.get("hourly_rate"),
        "rate_per_hour": int(profile.get("hourly_rate") or profile.get("rate_per_hour") or 150),
        "is_available": True,
        "approval_status": "pending",
    }

    lat = profile.get("lat")
    lng = profile.get("lng")
    if lat is not None and lng is not None:
        worker_data["location"] = f"POINT({lng} {lat})"

    supabase.table("workers").insert(worker_data).execute()
    return {"message": "Worker registered", "uid": uid, "role": "worker"}
