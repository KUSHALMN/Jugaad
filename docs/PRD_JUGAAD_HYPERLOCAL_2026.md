# 📄 Product Requirement Document (PRD) — Jugaad Hyperlocal Platform

> **Document Owner:** Lead Product Manager & Principal Systems Architect  
> **Status:** Production Ready • v2.0  
> **Target Market:** Tier-2 and Tier-3 Indian Metropolitan Hubs (Launch: Mysuru, Karnataka)

---

## 1. 🎯 Executive Vision & Problem Statement

In India's Tier-2 and Tier-3 cities, home and commercial trade repair (electricians, plumbers, carpenters, phone/laptop mechanics) remains an unorganized, high-friction market:
1. **Customer Frustration:** Opacity in arrival times, unverified technician security risks, doorstep price gouging, and cash disputes.
2. **Worker Exploitation:** Long gaps between jobs, delayed platform settlements, high middleman commissions, and severe smartphone battery kill rates on low-cost devices.
3. **The Jugaad Solution:** A low-latency, zero-trust hyperlocal service exchange guaranteeing **15–30 minute doorstep arrivals**, **two-tier standardized pricing (Visiting Fee + Digital Rate Card)**, **instant UPI payouts with soundbox feedback**, and **dual-PIN doorstep security**.

---

## 2. 📊 North Star Metrics & SLOs

| Dimension | Metric | Pilot Target (Mysuru) | Scale Target (Karnataka) |
| :--- | :--- | :--- | :--- |
| **Liquidity & Matching** | Request-to-Acceptance Time (P90) | < 45 seconds | < 30 seconds |
| **Doorstep SLA** | Arrival Time from Acceptance (P90) | < 25 minutes | < 20 minutes |
| **Fulfillment Rate** | % of Created Jobs Successfully Completed | > 92.0% | > 96.5% |
| **FinTech Settlement** | Time to Worker Bank Credit (P95) | < 15 seconds | < 5 seconds |
| **Dispute Rate** | % Jobs Escalated to Operations | < 1.5% | < 0.8% |
| **Worker Retention** | 30-Day Partner Activity Retention | > 75% | > 85% |

---

## 3. 🛡️ System Architecture & Reliability Pillars

```
                               ┌────────────────────────────────────────────────────────┐
                               │                    CLIENT APPLICATIONS                 │
                               └────────────────────────────────────────────────────────┘
                                      │                                           │
                        ┌─────────────┴─────────────┐                             │
                        ▼                           ▼                             ▼
             ┌─────────────────────┐     ┌─────────────────────┐       ┌─────────────────────┐
             │   Customer Portal   │     │   Partner Portal    │       │   Admin Operations  │
             │   (Flutter Mobile)  │     │  (Foreground Gps)   │       │   (React 18 Console)│
             └─────────────────────┘     └─────────────────────┘       └─────────────────────┘
                        │                           │                             │
                        │                           │                             │
                        └─────────────┬─────────────┘                             │
                                      ▼                                           ▼
             ┌──────────────────────────────────────────────────────────────────────────┐
             │                 FASTAPI ASYNC GATEWAY / DISTRIBUTED CORE                 │
             │     • Redis GEO Hot Cache              • Strict DAG State Machine        │
             │     • Two-Tier Rate Card Engine        • Automated Razorpay UPI Payouts  │
             │     • Liquidity Cluster SLA Escalator  • HMAC Family Safety Web Tracking │
             └──────────────────────────────────────────────────────────────────────────┘
```

### The 6 Core Engineering Pillars:
1. **Dual-Tier Spatial Telemetry:** Sub-millisecond Redis GEO ingestion eliminates database table bloat and connection exhaustion while buffering live coordinates during en-route tracking.
2. **Strict DAG State Machine:** Prevents out-of-order state transitions from elevator/basement offline queues and automatically generates dispute incidents when collisions occur.
3. **Automated UPI Payout Queue:** Dispatches instant earnings with 1% Section 194O TDS compliance, distributed Redis idempotency, and audible soundbox chimes.
4. **Two-Tier Transparent Pricing:** ₹99 standard visiting fee plus itemized in-app repair rate cards eliminates doorstep price bargaining and off-app platform disintermediation.
5. **Family Safety Web Tracking:** HMAC-signed public URLs shared via WhatsApp give family members real-time arrival tracking without app downloads.
6. **Supply Retention Engine:** Active duty hour tracking, daily floor earnings guarantees (₹400/4h), and rain surge multipliers preserve worker liquidity.
