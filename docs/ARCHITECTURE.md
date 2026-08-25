# 🏛️ Jugaad System Architecture & Flow

This document details the architectural blueprints, communication protocols, and state machine lifecycles powering the Jugaad ecosystem.

---

## 1. System Components

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   User Mobile   │       │  Worker Mobile  │       │  Admin Console  │
│ (Flutter Client)│       │ (Flutter Client)│       │(React 18 + Vite)│
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         ▼                         ▼                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       FastAPI Gateway Layer                         │
│   • Request Authentication (Firebase/Supabase)                      │
│   • Redis Rate Limiting & Spatial Caching                           │
│   • Dynamic Config Injection                                        │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                ▼                  ▼                  ▼
     ┌────────────────────┐ ┌─────────────┐ ┌────────────────────┐
     │ Supabase Database  │ │ Redis Store │ │ External Services  │
     │ • PostgreSQL       │ │ • Location  │ │ • Firebase FCM     │
     │ • PostGIS Spatial  │ │ • Rate caps │ │ • Razorpay Gateway │
     │ • Row Level Sec.   │ └─────────────┘ └────────────────────┘
     └────────────────────┘
```

---

## 2. Job Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> Pending: User submits job request
    Pending --> Assigned: Worker accepts via radar
    Pending --> Expired: Countdown timer reaches 0
    Assigned --> EnRoute: Worker starts travel
    EnRoute --> InProgress: Worker arrives & starts work
    InProgress --> Completed: Worker finishes & generates invoice
    Completed --> Paid: User completes payment (Razorpay / Cash)
    Paid --> [*]
    
    Pending --> Cancelled: User cancels before match
    Assigned --> Cancelled: Customer/Worker cancels (Reason required)
```

---

## 3. Worker KYC Verification Flow

```mermaid
sequenceDiagram
    autonumber
    actor W as Worker
    participant A as Mobile App
    participant G as FastAPI Gateway
    participant DB as Supabase DB
    actor AD as Admin Console
    participant FCM as Firebase FCM

    W->>A: Completes 3-Step Registration Wizard
    A->>G: Uploads Aadhaar + Profile (POST /v1/workers/register)
    G->>DB: Saves worker record (status = 'pending')
    DB-->>AD: Real-time update in verification queue
    AD->>G: Approves worker (POST /v1/workers/{id}/approve)
    G->>DB: Atomically sets status = 'approved', is_available = true
    G->>FCM: Dispatches instant approval alert
    FCM-->>W: Push notification: "You are approved! Start accepting jobs."
```
