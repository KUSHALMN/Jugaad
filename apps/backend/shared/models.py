# shared/models.py
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from datetime import datetime, timezone, timedelta
from typing import Optional, Literal
import re

# IST timezone constant — used across all services
IST = timezone(timedelta(hours=5, minutes=30))


def now_ist() -> datetime:
    """Return current datetime in IST (Asia/Kolkata)."""
    return datetime.now(IST)


VALID_SKILLS = [
    "electrician", "plumber", "laptop_repair", "phone_repair",
    "carpenter", "painter", "ac_service", "cleaning",
    "car_wash", "bike_mechanic", "hair_salon", "spa_massage",
    "water_leakage", "power_outage", "locked_out_of_home",
    "blocked_toilet_drain", "water_pump_failure", "ac_breakdown",
    "electrical_short_circuit", "emergency_plumbing", "emergency_electrician"
]


# ─── Job Models ──────────────────────────────────────────────────

class CreateJobRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    skill: str
    lat: float
    lng: float
    description: str = Field(..., min_length=10)
    urgency: Literal["now", "scheduled"]
    scheduled_at: Optional[datetime] = None
    category: str = ""
    budget: float = 0
    job_type: Optional[Literal["normal", "emergency"]] = "normal"
    service_fee_type: Optional[Literal["normal", "emergency"]] = "normal"
    surcharge_amount: Optional[float] = 0.0

    @field_validator("skill")
    @classmethod
    def validate_skill(cls, v: str) -> str:
        if v not in VALID_SKILLS:
            raise ValueError(f"Skill '{v}' is not in valid skills list: {VALID_SKILLS}")
        return v

    @field_validator("scheduled_at", mode="before")
    @classmethod
    def ensure_tz_aware(cls, v):
        """Ensure scheduled_at is timezone-aware. Assume IST if naive."""
        if v is None:
            return v
        if isinstance(v, str):
            v = datetime.fromisoformat(v)
        if v.tzinfo is None:
            v = v.replace(tzinfo=IST)
        return v

    @model_validator(mode="after")
    def check_scheduled_at(self) -> "CreateJobRequest":
        if self.urgency == "scheduled" and self.scheduled_at is None:
            raise ValueError("scheduled_at must be provided when urgency is 'scheduled'")
        return self


class JobRequestCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    user_id: str
    service_type: str
    lat: float
    lng: float


class JobRequestResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    job_request_id: str
    status: str
    message: str = ""


class JobRespondRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    worker_id: str
    action: Literal["accept", "reject"]


class JobCancelRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    user_id: str


class FCMTokenUpdate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    fcm_token: str


class AcceptJobRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    worker_id: str
    expected_version: int
    agreed_price: Optional[float] = None



class CompleteJobRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    confirmer: Literal["user", "worker"]


class RejectJobRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    worker_id: str
    reason: str = ""


# ─── Worker Models ───────────────────────────────────────────────

class WorkerHeartbeatRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    lat: float
    lng: float


class WorkerRegistrationRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: str
    phone: str
    skills: list[str]
    rate_per_hour: float = Field(..., gt=0)
    area: Literal["vijayanagar_mysuru", "kuvempunagar_mysuru"]

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not re.match(r"^\+91\d{10}$", v):
            raise ValueError("Phone number must be in E.164 format (+91XXXXXXXXXX)")
        return v

    @field_validator("skills")
    @classmethod
    def validate_skills(cls, v: list[str]) -> list[str]:
        for skill in v:
            if skill not in VALID_SKILLS:
                raise ValueError(f"Skill '{skill}' is not in valid skills list: {VALID_SKILLS}")
        return v


# ─── User / Profile Models (backward-compat) ────────────────────

class UserProfile(BaseModel):
    """User profile model for registration and updates."""
    display_name: str
    phone: str
    email: str | None = None
    lat: float | None = None
    lng: float | None = None

    model_config = ConfigDict(from_attributes=True)


class WorkerProfile(BaseModel):
    """Worker profile model for registration and updates."""
    name: str
    phone: str
    email: str | None = None
    skills: list[str] = []
    lat: float | None = None
    lng: float | None = None
    approval_status: str = "PENDING"

    model_config = ConfigDict(from_attributes=True)


class ReviewRequest(BaseModel):
    """Review submission model."""
    workerId: str
    rating: float
    comment: str | None = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, v):
        if not (1.0 <= v <= 5.0):
            raise ValueError("Rating must be between 1.0 and 5.0")
        return v


# ─── Price Lock / Change Request Models ──────────────────────────

class PriceChangeRequestInput(BaseModel):
    """Request model for worker to propose a price change."""
    model_config = ConfigDict(extra="ignore")

    new_price: float = Field(..., gt=0)
    reason: str = Field(..., min_length=5)


class PriceChangeResponseInput(BaseModel):
    """Request model for customer to accept or reject a price change."""
    model_config = ConfigDict(extra="ignore")

    approved: bool

