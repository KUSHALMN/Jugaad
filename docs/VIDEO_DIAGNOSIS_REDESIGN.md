# 30s Video Diagnosis — UI/UX Elevation & Architecture Specification

## 1. Overview
The **30s Video Diagnosis** feature replaces legacy circular story icons with a unified, high-contrast, tactile banner card designed for high readability in ambient daylight and instant cognitive clarity for homeowners across Karnataka.

---

## 2. Visual Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ [📹 Camera Icon]  30s Video Diagnosis  [📖 GUIDES]                          [▶ 30s]   │
│                   Record a short video (30s) and get quick help...                    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────┐  │
│ │ ❄️  AC        │ │ ⚡ Fan Humming│ │ 💧 Low Tap    │ │ 🔌 MCB        │ │ 🚿 Geyser │  │
│ │    Leak   [>] │ │    Noise  [>] │ │    Flow   [>] │ │    Trip   [>] │ │    Cold [>]│  │
│ └───────────────┘ └───────────────┘ └───────────────┘ └───────────────┘ └───────────┘  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Component Details
1. **Hero Header Card**:
   - Background: Soft dual-gradient tint (`#F0F5FF` to `#F8FAFD`) with rounded 22px corners.
   - Camera Icon Badge: Indigo rounded square (`#4F46E5`) with drop shadow.
   - Verified Badge: Mint green pill badge `[📖 GUIDES]` (`#DCFCE7` / `#15803D`).
   - Playback Slate: Visual clapperboard pill displaying `▶ 30s`.

2. **Issue Diagnosis Cards**:
   - **AC Leaking Issue**: Ice Blue (`#F0F9FF`), Snowflake icon, `#0284C7` accent.
   - **Fan Humming Noise**: Warm Amber (`#FFFBEB`), Bolt icon, `#D97706` accent.
   - **Low Tap Water Flow**: Sky Blue (`#EFF6FF`), Water droplet icon, `#2563EB` accent.
   - **MCB Tripping**: Soft Rose (`#FFF1F2`), Power plug icon, `#E11D48` accent.
   - **Geyser Not Heating**: Mint Emerald (`#F0FDF4`), Shower icon, `#16A34A` accent.

3. **Interactive Modals**:
   - **Video Recorder Sheet**: Full 30-second camera capture bottom sheet with instant AI analysis & technician dispatch.
   - **Diagnosis Step Modal**: 3-step action checklist, estimated service fare, and 1-tap verified technician booking.

---

## 3. Test Coverage
- `test/features/user/video_diagnosis_redesign_test.dart`: 4 comprehensive widget tests covering rendering, 2-line card layouts, modal interactions, and camera triggers.
- Fully verified with `flutter analyze` (0 issues) and `flutter test` (100% passing).
