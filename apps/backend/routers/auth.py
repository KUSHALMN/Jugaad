from fastapi import APIRouter, Request, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List, Optional
from shared.database import supabase
from shared.auth import verify_firebase_token
from services.sms_service import sms_service
from utils.security import normalize_phone_e164
import random
import time
import re
from shared import redis_client

router = APIRouter()

# Resilient in-memory fallback stores if Redis is unreachable
_FALLBACK_OTP_STORE: dict[str, tuple[float, str, int]] = {}
_LOCAL_RATE_LIMITS: dict[str, list[float]] = {}
_LOCAL_PHONE_LOCKOUTS: dict[str, float] = {}

def check_sliding_rate_limit(key: str, limit: int, window_sec: int) -> tuple[bool, int]:
    """
    Sliding-window rate limiter using Redis sorted sets with in-memory fallback.
    Returns (is_allowed, retry_after_seconds).
    """
    now = time.time()
    r = redis_client.get_client()
    if r:
        try:
            r_key = f"ratelimit:sliding:{key}"
            pipe = r.pipeline()
            pipe.zremrangebyscore(r_key, 0, now - window_sec)
            pipe.zadd(r_key, {str(now): now})
            pipe.zcard(r_key)
            pipe.expire(r_key, window_sec)
            results = pipe.execute()
            count = results[2]
            if count > limit:
                return False, window_sec
            return True, 0
        except Exception:
            pass

    # In-memory sliding window fallback
    timestamps = _LOCAL_RATE_LIMITS.setdefault(key, [])
    cutoff = now - window_sec
    _LOCAL_RATE_LIMITS[key] = [t for t in timestamps if t > cutoff]
    if len(_LOCAL_RATE_LIMITS[key]) >= limit:
        oldest = _LOCAL_RATE_LIMITS[key][0]
        retry_after = max(1, int(oldest + window_sec - now))
        return False, retry_after

    _LOCAL_RATE_LIMITS[key].append(now)
    return True, 0

def is_phone_locked(phone: str) -> tuple[bool, int]:
    """Check if phone is currently locked out due to excessive failed OTP attempts."""
    now = time.time()
    r = redis_client.get_client()
    lock_key = f"otp_lockout:{phone}"
    if r:
        try:
            ttl = r.ttl(lock_key)
            if ttl and ttl > 0:
                return True, ttl
        except Exception:
            pass
    if phone in _LOCAL_PHONE_LOCKOUTS:
        expiry = _LOCAL_PHONE_LOCKOUTS[phone]
        if expiry > now:
            return True, int(expiry - now)
        else:
            del _LOCAL_PHONE_LOCKOUTS[phone]
    return False, 0

def lock_phone(phone: str, duration_sec: int = 900):
    """Enforce abuse lockout for a phone number."""
    now = time.time()
    r = redis_client.get_client()
    if r:
        try:
            r.set(f"otp_lockout:{phone}", "locked", ex=duration_sec)
        except Exception:
            pass
    _LOCAL_PHONE_LOCKOUTS[phone] = now + duration_sec

def is_rate_limited(key: str, limit: int = 5, window: int = 60) -> bool:
    allowed, _ = check_sliding_rate_limit(key, limit=limit, window_sec=window)
    return not allowed

class LoginResponse(BaseModel):
    message: str
    uid: str
    role: str

class SendOtpRequest(BaseModel):
    phone: str = Field(..., pattern=r'^\+?[0-9\s\-]{10,18}$')

class VerifyOtpRequest(BaseModel):
    phone: str = Field(..., pattern=r'^\+?[0-9\s\-]{10,18}$')
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

    # Canonicalize phone to E.164
    try:
        norm_phone = normalize_phone_e164(req.phone)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

    # 1. Check abuse lockout
    locked, retry_lock = is_phone_locked(norm_phone)
    if locked:
        raise HTTPException(
            status_code=429,
            detail=f"Phone number temporarily locked due to excessive invalid attempts. Please wait {retry_lock}s."
        )

    # 2. Strict sliding-window rate limit by phone (max 3 per 10 mins)
    allowed_phone, retry_p = check_sliding_rate_limit(f"phone:{norm_phone}", limit=3, window_sec=600)
    if not allowed_phone:
        raise HTTPException(
            status_code=429,
            detail=f"Too many OTP requests for this phone number. Please try again in {retry_p} seconds."
        )

    # 3. Strict sliding-window rate limit by client IP (max 5 per 10 mins)
    allowed_ip, retry_ip = check_sliding_rate_limit(f"ip:{client_ip}", limit=5, window_sec=600)
    if not allowed_ip:
        raise HTTPException(
            status_code=429,
            detail=f"Too many OTP requests from your network. Please try again in {retry_ip} seconds."
        )
    
    # Generate random 6-digit OTP
    otp = str(random.randint(100000, 999999))
    
    # Store OTP with 5 minute TTL in Redis (or in-memory failover)
    redis_stored = False
    r = redis_client.get_client()
    if r:
        try:
            r.set(f"otp:{norm_phone}", otp, ex=300)
            redis_stored = True
        except Exception:
            pass
            
    if not redis_stored:
        # Fallback to local memory store
        _FALLBACK_OTP_STORE[norm_phone] = (time.time(), otp, 0)

    # Send via sms_service
    await sms_service.send_otp(norm_phone, otp)
    return {"message": "OTP sent successfully", "phone": norm_phone}

@router.post("/verify-otp")
async def verify_otp(req: VerifyOtpRequest):
    from core.config import settings

    try:
        norm_phone = normalize_phone_e164(req.phone)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

    # Check lockout
    locked, retry_lock = is_phone_locked(norm_phone)
    if locked:
        raise HTTPException(
            status_code=429,
            detail=f"Phone number temporarily locked due to excessive invalid attempts. Please wait {retry_lock}s."
        )

    r = redis_client.get_client()
    fail_key = f"otp_fails:{norm_phone}"
    
    if r:
        try:
            fail_count = int(r.get(fail_key) or 0)
            if fail_count >= 5:
                lock_phone(norm_phone, duration_sec=900)
                raise HTTPException(status_code=429, detail="Too many invalid OTP attempts. Phone locked for 15 minutes.")

            stored_otp = r.get(f"otp:{norm_phone}")
            if stored_otp and stored_otp == req.otp:
                r.delete(f"otp:{norm_phone}")
                r.delete(fail_key)
                _FALLBACK_OTP_STORE.pop(norm_phone, None)
                return {"message": "OTP verified successfully", "phone": norm_phone}
            elif stored_otp:
                r.incr(fail_key)
                r.expire(fail_key, 300)
                raise HTTPException(status_code=400, detail="Invalid OTP")
        except HTTPException:
            raise
        except Exception:
            pass

    # Check fallback memory store if Redis is unavailable
    if norm_phone in _FALLBACK_OTP_STORE:
        created_at, valid_otp, fails = _FALLBACK_OTP_STORE[norm_phone]
        if (time.time() - created_at) < 300.0:
            if fails >= 5:
                lock_phone(norm_phone, duration_sec=900)
                raise HTTPException(status_code=429, detail="Too many invalid OTP attempts. Phone locked for 15 minutes.")
            if req.otp == valid_otp:
                del _FALLBACK_OTP_STORE[norm_phone]
                return {"message": "OTP verified successfully", "phone": norm_phone}
            else:
                _FALLBACK_OTP_STORE[norm_phone] = (created_at, valid_otp, fails + 1)
                raise HTTPException(status_code=400, detail="Invalid OTP")
        else:
            del _FALLBACK_OTP_STORE[norm_phone]

    # Strictly isolate dev fallback to local debug environments
    if settings.ENV == "local" and settings.DEBUG and req.otp in ("123456", "000000"):
        return {"message": "OTP verified successfully (local dev only)", "phone": norm_phone}

    raise HTTPException(status_code=400, detail="OTP expired or not found. Please request a new OTP.")

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
    normalized_phone = None
    if profile.phone:
        try:
            normalized_phone = normalize_phone_e164(profile.phone)
        except ValueError:
            normalized_phone = profile.phone

    supabase.table("users").upsert({
        "id": uid,
        "firebase_uid": uid,
        "phone": normalized_phone,
        "name": profile.name,
        "email": profile.email,
        "role": "employer",
    }).execute()
    return {"message": "User registered", "uid": uid, "role": "employer"}

@router.post("/register-worker")
def register_worker(profile: RegisterWorkerRequest, uid: str = Depends(verify_firebase_token)):
    normalized_phone = None
    if profile.phone:
        try:
            normalized_phone = normalize_phone_e164(profile.phone)
        except ValueError:
            normalized_phone = profile.phone

    supabase.table("users").upsert({
        "id": uid,
        "firebase_uid": uid,
        "phone": normalized_phone,
        "name": profile.name,
        "email": profile.email,
        "role": "worker",
    }).execute()

    worker_data = {
        "id": uid,
        "name": profile.name,
        "phone": normalized_phone,
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
