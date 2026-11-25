# User Account Profile — UI/UX Redesign Specification

## 1. Overview
The **User Account** (`UserPortalScreen`) screen has been redesigned for instant clarity, trust, and seamless portal switching between Consumer and Technician modes.

---

## 2. Visual Structure

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ <  User Account                                                      [✏️ Edit Profile] │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  ╭──────╮  nisha                                                      [🏙️ Watermark]  │
│  │  NI  │  📞 +919791116574  |  📍 Mysuru                                             │
│  ╰──────📷  [📅 Member since Jun 2026]                                                 │
│             ┌───────────────────────────┐  ┌───────────────────────────┐               │
│             │ 📅  0                     │  │ ⭐  —                     │               │
│             │     Total Bookings        │  │     Your Rating           │               │
│             └───────────────────────────┘  └───────────────────────────┘               │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [📚] Portal Selector        ┌──────────────────────────┐ ┌───────────────────────────┐ │
│      Choose how to use      │ 👤 User Portal       [✓] │ │ 👷 Worker Portal          │ │
│      Jugaad                 │ Book services, track...  │ │ Offer your services...    │ │
│                             └──────────────────────────┘ └───────────────────────────┘ │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ My Bookings                                                                View all →  │
│ ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│ │                                    [📅]                                            │ │
│ │                               No bookings yet                                      │ │
│ │                       Your booked services will appear here.                       │ │
│ │                          [🔍 Find & Book a Service]                                │ │
│ └────────────────────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Key Enhancements
1. **Pill `Edit Profile` Button**: Crisp emerald outlined action pill in the AppBar.
2. **Hero Profile Card**:
   - Soft white-to-mint gradient with subtle cityscape watermark.
   - Avatar with interactive emerald camera badge.
   - Contact & City inline row, `Member since` pill, and Mint (`Total Bookings`) + Amber (`Your Rating`) KPI cards.
3. **Rich Dual-Card Portal Selector**:
   - Active `User Portal` card in solid emerald (`#16A34A`) with checkmark badge.
   - Interactive `Worker Portal` card with hardhat icon and subtitle.
4. **Actionable `My Bookings` Empty State**:
   - Clean bordered empty state card with `Find & Book a Service` CTA button.
