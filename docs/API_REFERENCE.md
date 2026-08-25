# 🔌 Jugaad REST API Reference

All backend routes are served via the FastAPI gateway at `http://localhost:8000` (or production Cloud Run endpoints).

---

## Base URLs
- **Development**: `http://localhost:8000`
- **Prefixes**: `/v1` or `/api/v1`

---

## 1. Authentication & Users
- `POST /v1/auth/verify`: Validates Firebase JWT token and returns internal user profile.
- `GET /v1/users/profile`: Retrieves customer metadata and active bookings.
- `PUT /v1/users/profile`: Updates customer name, phone number, and preferences.
- `GET /v1/users/addresses`: Lists saved addresses (Home, Work, Other).

---

## 2. Worker Operations
- `GET /v1/workers/nearby`: Spatial radius query for nearby trade professionals.
  - Query parameters: `lat`, `lng`, `category`, `radius_km`.
- `POST /v1/workers/register`: Submits 3-step KYC application with Aadhaar document.
- `POST /v1/workers/{id}/approve`: **(Admin Only)** Approves worker profile and broadcasts FCM alert.
- `POST /v1/workers/{id}/reject`: **(Admin Only)** Rejects worker profile with specified rationale.
- `POST /v1/workers/heartbeat`: Periodic GPS coordinate update for online workers.

---

## 3. Jobs & Booking Lifecycle
- `POST /v1/jobs/create`: Creates a new service request and initiates spatial matching.
- `GET /v1/jobs/{id}`: Retrieves comprehensive job tracking details.
- `POST /v1/jobs/{id}/accept`: Worker accepts the incoming booking.
- `POST /v1/jobs/{id}/status`: Transitions job state (`en_route`, `in_progress`, `completed`, `cancelled`).

---

## 4. Platform Configuration
- `GET /v1/platform/config`: Returns active emergency dispatch radius and surge pricing multipliers.
- `PUT /v1/platform/config`: **(Admin Only)** Updates platform parameters in real-time.
