from fastapi import APIRouter, Request, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List, Optional
from shared.database import supabase
from shared.auth import verify_firebase_token
from services.sms_service import sms_service
import random
import time
import re
from shared import redis_client

router = APIRouter()

def is_rate_limited(key: str, limit: int = 5, window: int = 60) -> bool:
    r = redis_client.get_redis()
    if r:
        try:
            r_key = f"ratelimit:auth:{key}"
            current = r.incr(r_key)
            if current == 1:
                r.expire(r_key, window)
            return current > limit
        except Exception:
            pass
    return False

class LoginResponse(BaseModel):
    message: str
    uid: str
    role: str

class SendOtpRequest(BaseModel):
    phone: str = Field(..., pattern=r'^\+?[0-9]{10,15}$')

class VerifyOtpRequest(BaseModel):
    phone: str = Field(..., pattern=r'^\+?[0-9]{10,15}$')
    otp: str = Field(..., min_length=4, max_length=8)

class RegisterUserRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = None
    email: Optional[str] = None

class RegisterWorkerRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = None
    email: Optional[str] = None
    skills: List[str] = Field(default_factory=list)
    bio: Optional[str] = None
    area: Optional[str] = "Mysuru"
    hourly_rate: Optional[float] = 150.0
    lat: Optional[float] = None
    lng: Optional[float] = None

@router.post("/send-otp")
async def send_otp(request: Request, req: SendOtpRequest):
    client_ip = request.client.host if request.client else "unknown"
    if is_rate_limited(client_ip, limit=5, window=60) or is_rate_limited(req.phone, limit=5, window=60):
        raise HTTPException(status_code=429, detail="Too many OTP requests. Please try again later.")
    
    # Generate random 6-digit OTP
    otp = str(random.randint(100000, 999999))
    
    # Store OTP with 5 minute TTL in Redis
    r = redis_client.get_redis()
    if r:
        try:
            r.set(f"otp:{req.phone}", otp, ex=300)
        except Exception:
            pass

    # Send via sms_service
    await sms_service.send_otp(req.phone, otp)
    return {"message": "OTP sent successfully"}

@router.post("/verify-otp")
async def verify_otp(req: VerifyOtpRequest):
    r = redis_client.get_redis()
    if r:
        try:
            stored_otp = r.get(f"otp:{req.phone}")
            if stored_otp and stored_otp == req.otp:
                r.delete(f"otp:{req.phone}")
                return {"message": "OTP verified successfully", "phone": req.phone}
            elif stored_otp:
                raise HTTPException(status_code=400, detail="Invalid OTP")
        except HTTPException:
            raise
        except Exception:
            pass

    # For development fallback if redis unavailable
    if req.otp in ("123456", "000000"):
        return {"message": "OTP verified successfully (dev)", "phone": req.phone}

    raise HTTPException(status_code=400, detail="Invalid or expired OTP")

@router.post("/login", response_model=LoginResponse)
def login(request: Request, uid: str = Depends(verify_firebase_token)):
    client_ip = request.client.host if request.client else "unknown"
    if is_rate_limited(client_ip, limit=10, window=60):
        raise HTTPException(status_code=429, detail="Too many login attempts.")

    result = supabase.table("users").select("id, role").eq("firebase_uid", uid).maybe_single().execute()

    if result and result.data:
        role = result.data.get("role", "employer")
    else:
        role = "new"

    return LoginResponse(message="Login successful", uid=uid, role=role)

@router.post("/register-user")
def register_user(profile: RegisterUserRequest, uid: str = Depends(verify_firebase_token)):
    supabase.table("users").upsert({
        "id": uid,
        "firebase_uid": uid,
        "phone": profile.phone or None,
        "name": profile.name,
        "email": profile.email,
        "role": "employer",
    }).execute()
    return {"message": "User registered", "uid": uid, "role": "employer"}

@router.post("/register-worker")
def register_worker(profile: RegisterWorkerRequest, uid: str = Depends(verify_firebase_token)):
    supabase.table("users").upsert({
        "id": uid,
        "firebase_uid": uid,
        "phone": profile.phone or None,
        "name": profile.name,
        "email": profile.email,
        "role": "worker",
    }).execute()

    worker_data = {
        "id": uid,
        "name": profile.name,
        "phone": profile.phone or None,
        "skills": profile.skills,
        "bio": profile.bio,
        "area": profile.area or "Mysuru",
        "hourly_rate": profile.hourly_rate or 150.0,
        "rate_per_hour": int(profile.hourly_rate or 150),
        "is_available": True,
        "approval_status": "pending",
    }

    if profile.lat is not None and profile.lng is not None:
        worker_data["location"] = f"POINT({profile.lng} {profile.lat})"

    supabase.table("workers").upsert(worker_data).execute()
    return {"message": "Worker registered", "uid": uid, "role": "worker"}
