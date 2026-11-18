# Jugaad Backend API Reference

Base URL in development: `http://localhost:8000/api/v1`  
Production URL: `https://api.jugaad.app/v1`

---

## Authentication
All authenticated requests must include the user's Supabase JWT in the `Authorization` header:
```http
Authorization: Bearer <SUPABASE_JWT_TOKEN>
```

---

## 1. Jobs & Bookings

### `POST /jobs`
Creates a new on-demand service booking.
* **Request Body**:
  ```json
  {
    "user_id": "usr_94829102",
    "service_id": "plumbing",
    "address": "42, 2nd Main, Gokulam, Mysuru, Karnataka",
    "latitude": 12.3312,
    "longitude": 76.6214,
    "problem_description": "Water leaking from main valve",
    "express_15min": true
  }
  ```
* **Response (201 Created)**:
  ```json
  {
    "job_id": "job_e98f21bc",
    "status": "matching",
    "estimated_base_fare": 199.00,
    "created_at": "2026-11-18T14:30:00Z"
  }
  ```

### `POST /jobs/{job_id}/start-pin`
Verifies the customer's 4-digit arrival PIN to initiate work.
* **Request Body**:
  ```json
  {
    "start_pin": "4821"
  }
  ```
* **Response (200 OK)**:
  ```json
  {
    "success": true,
    "status": "in_progress",
    "started_at": "2026-11-18T14:45:00Z"
  }
  ```

### `POST /jobs/{job_id}/complete`
Verifies completion PIN, checks mandatory before/after photo proof, and initiates escrow settlement.
* **Request Body**:
  ```json
  {
    "completion_pin": "8492",
    "before_photo_url": "https://storage.jugaad.app/photos/before.jpg",
    "after_photo_url": "https://storage.jugaad.app/photos/after.jpg"
  }
  ```
* **Response (200 OK)**:
  ```json
  {
    "success": true,
    "status": "completed",
    "warranty_id": "JGD-WRN-88492"
  }
  ```

---

## 2. Spatial Worker Queries

### `GET /workers/nearby`
Finds verified, active technicians within the service radius using PostGIS indexing.
* **Query Parameters**:
  - `lat` (float): Latitude
  - `lng` (float): Longitude
  - `radius_km` (float, default: `5.0`)
  - `service` (string, optional)
* **Response (200 OK)**:
  ```json
  {
    "count": 3,
    "workers": [
      {
        "id": "wrk_1",
        "name": "Ramesh Kumar",
        "rating": 4.9,
        "distance_km": 1.2,
        "eta_mins": 8,
        "kyc_verified": true
      }
    ]
  }
  ```

---

## 3. Payments & Escrow Webhooks

### `POST /payments/webhook`
Idempotent webhook handler verifying HMAC SHA256 signature from Razorpay.
* **Headers**:
  ```http
  X-Razorpay-Signature: <HMAC_SHA256_HEX>
  ```
* **Events Handled**:
  - `payment.captured`: Credits technician escrow balance.
  - `payment.failed`: Triggers failover alert and fallback payment request.
  - `payout.processed`: Dispatches instant UPI notification to technician.
