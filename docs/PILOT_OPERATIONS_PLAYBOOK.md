# 📘 Mysuru Pilot Launch Operations Playbook

> **Target Geofence:** Gokulam, Vijayanagar, Jayalakshmipuram, Kuvempunagar  
> **Launch Date:** Q4 2026 • Tier-2 Indian Market Operations Guide

---

## 1. 👷 Partner Onboarding & Ground KYC Verification
1. **Physical Trade Verification:** Every electrician, plumber, or technician completes a 15-minute hands-on bench test at the local Hub.
2. **Document Ingestion:**
   - Aadhaar Card (front + back) with OCR number masking.
   - Bank Passbook / Cancelled Cheque / UPI VPA for penny-drop verification.
   - Police verification clearance or local reference affidavit.
3. **Hardware & App Configuration:**
   - Whitelist Jugaad app in device settings (`BatteryOptimizationSheet`).
   - Soundbox chime test: verify maximum audio volume for incoming booking alerts.

---

## 2. ⚡ Dispatch Escalation & Ground SOP
* **0–45s:** First-tier radial broadcast to active partners within 3 km.
* **45–60s:** High-priority buzzer sound dispatched to top-rated nearby partners.
* **> 60s (SLA Breach):** Radius automatically expands to 15 km; automated webhook alerts internal ops team desk for telephone concierge assist.

---

## 3. 🚨 Fraud Prevention & Doorstep Integrity SOP
* **PIN Handshake Enforcement:** Technician must collect 4-digit arrival PIN from customer before work commences.
* **Bypass Trigger Audit:** If emergency manual bypass is selected, GPS proximity must verify < 100m distance from customer coordinates, and mandatory front-camera selfie must be uploaded.
* **Dispute Arbitration:** Operations desk arbitrates disputes within 15 minutes using the Admin Console timeline viewer, triggering either escrow payout or customer refund.
