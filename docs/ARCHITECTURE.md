# Jugaad System Architecture & Engineering Specifications

This document outlines the core architectural principles, state management topologies, and real-time synchronization pipelines powering the **Jugaad** hyperlocal services platform.

```mermaid
flowchart TD
    subgraph Clients["Frontend Layer"]
        UserApp["Mobile User Portal (Flutter)"]
        WorkerApp["Mobile Technician Portal (Flutter)"]
        AdminDashboard["Web Admin Dashboard (Vite + React)"]
    end

    subgraph Gateway["Edge & Gateway"]
        APIGateway["FastAPI Gateway (Uvicorn / SSL)"]
        RateLimiter["Token Bucket Rate Limiter"]
    end

    subgraph Data["Data & Realtime Layer"]
        Postgres["PostgreSQL with PostGIS"]
        Realtime["Supabase Realtime Engine (WebSockets)"]
        Storage["Supabase S3 Bucket (KYC & Job Photos)"]
    end

    subgraph External["External Integrations"]
        Razorpay["Razorpay Escrow & Payout Switch"]
        GoogleMaps["Google Maps Platform (Geocoding)"]
        FCM["Firebase Cloud Messaging"]
    end

    UserApp <-->|WebSocket / REST| APIGateway
    WorkerApp <-->|WebSocket / REST| APIGateway
    AdminDashboard <-->|REST| APIGateway

    APIGateway <--> Postgres
    APIGateway <--> Realtime
    APIGateway <--> Storage
    APIGateway <--> Razorpay
    APIGateway <--> FCM
    UserApp <--> GoogleMaps
    WorkerApp <--> GoogleMaps
```

---

## 1. Client Architecture (Flutter)
* **Architecture Pattern**: Feature-First Layered Architecture with clean domain, data, and presentation boundaries.
* **State Management**: **Flutter Riverpod** handles reactive state and stream subscriptions.
* **Navigation**: **GoRouter 17.x** provides declarative deep-linking and state restoration across web and mobile viewports.
* **Offline Resilience**: Offline actions (e.g. status updates, arrival pings) are queued in a persistent local queue (`OfflineQueueService`) and synchronized automatically upon reconnect.

---

## 2. Real-Time Telemetry & Tracking
* **Kalman Filtering (`KalmanLatLong`)**: Eliminates GPS jitter and noisy multipath reflections common in dense Indian urban corridors.
* **Dead Reckoning & Slerp Interpolation**: Coordinates between 1-second GPS packets are smoothly interpolated on the client canvas at 60 FPS.

---

## 3. Financial & Escrow Engine
* **Perforated Ticket Bill**: Scalloped bill with itemized base fee, materials with photo proof, and platform escrow fee.
* **Zero-Trust OTP Escrow Release**: Payments are held in escrow and released to the worker only upon verification of the customer's 4-digit PIN.
* **Instant Daily UPI Cashout**: Technicians can withdraw verified earnings directly to their bank account via IMPS/UPI with zero transaction fees.

---

## 4. Trust & Safety Infrastructure ("Jugaad Suraksha")
* **Aadhaar Biometric & KYC**: Government-verified identification with criminal record check.
* **1-Tap WhatsApp Live Status**: Pre-formatted WhatsApp share link allowing users to broadcast technician live status to family.
* **Emergency Dispatch**: 1-Tap direct dialing to National Police (112) and 24x7 Safety Command Center.
