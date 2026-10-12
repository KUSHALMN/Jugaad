# Jugaad Field Reliability, Verification Handshake & Anti-Fraud Architecture

## Overview
This document specifies the mission-critical systems deployed in Jugaad to guarantee operational reliability, fraud protection, and personal safety across urban and rural operating environments in India.

---

## 1. Zero-Cost Doorstep & Completion Handshake (Free In-App PIN)

### Problem
Traditional SMS OTPs cost ₹0.20–₹0.50 per SMS via third-party aggregators (Fast2SMS, MSG91, Twilio) and suffer from 30–90 second network latency in dense Indian localities.

### Solution: Cryptographic In-App Verification
1. **Server-Side Generation**:
   - `secrets.choice("0123456789")` generates random 4-digit codes: `start_pin` and `completion_pin`.
   - Stored in Postgres and cached in Redis.
2. **Role-Based Masking**:
   - When a worker calls `GET /v1/jobs/{id}`, the PINs are redacted (`null`).
   - The customer sees their PIN prominently on their screen.
3. **Doorstep Physical Handshake**:
   - Customer verbally shares `start_pin` upon worker arrival.
   - Worker enters code into `active_job_screen.dart` via `_showStartPinModal()`.
   - Verified via `POST /v1/jobs/{id}/start-with-pin`.
4. **Completion Handshake**:
   - Customer inspects completed work, shares `completion_pin`.
   - Verified via `POST /v1/jobs/{id}/complete-with-pin` alongside mandatory photo proof.
5. **Emergency Manual Bypass**:
   - If customer's phone battery died, partner can trigger an auditable emergency bypass with reason logging.

---

## 2. Offline Queue Sync (Zero-Signal Basements)

When gig workers operate in underground basements, concrete stairwells, or elevator shafts:
1. PIN verifications and status updates are optimistically applied to local state.
2. Enqueued into `OfflineQueueService` with mutation types:
   - `'start_with_pin'`
   - `'complete_with_pin'`
   - `'ack_arrival'`
   - `'complete_job'`
3. As soon as 4G/5G connectivity is restored, `OfflineSyncManager` automatically flushes pending mutations sequentially with retry backoff.

---

## 3. GPS Anti-Fraud & Mock Location Detection

### Threat Model
Gig workers installing Android "Fake GPS" or "Mock Location" apps to spoof their coordinates near high-demand localities or fake their arrival at customer premises.

### Defense Mechanism
1. In `heartbeat_service.dart`, every GPS coordinate is inspected:
   ```dart
   if (position.isMocked || lastKnown.isMocked) {
     // Suppress telemetry and flag security threat
     return Future.value(false);
   }
   ```
2. Dynamic location caching prevents hardcoded coordinates (e.g. Mysuru center) from polluting backend routing when GPS is temporarily indoor-attenuated.

---

## 4. Worker Safety SOS & Privacy Call Masking

1. **Partner Emergency SOS**:
   - Dedicated AppBar SOS button in both En Route and In Progress screens.
   - One-tap 112 police dialing and 24/7 Jugaad Partner Safety Desk helpline (`1800-890-5842`).
2. **Call Masking Relay**:
   - In-app notice and relay shielding protecting personal contact details of both female customers and partners.

---

## 5. Soundbox Audio & Tactile Feedback

- `SoundService` provides high-contrast sound chimes and multi-pattern haptics:
  - Attention-grabbing alert chime for incoming high-value leads while riding.
  - Satisfying double-click verification chime upon PIN entry.
  - Celebratory chime upon instant UPI wallet cashout.
