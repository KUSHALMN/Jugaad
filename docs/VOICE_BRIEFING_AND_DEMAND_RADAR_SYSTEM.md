# Voice Briefing & Demand Radar Ergonomics Specification

## 1. Executive Summary & Behavioral Psychology

In India's hyper-local home service ecosystem, trust and field efficiency determine platform retention:
1. **The Homeowner Trust Deficit ("Keli Thiliri" / "Sunke Samjho")**:
   - Elderly homeowners, non-English speakers, and busy consumers experience high anxiety during service settlement.
   - When presented with a dense digital bill or spare parts receipt, ambiguity leads to suspicions of technician extortion or off-platform markups.
   - **Solution**: A 1-tap trilingual audio briefing button (`VoiceBriefingPill`) right beside the bill breakdown. It plays a standardized 6-second spoken synthesis in Kannada, Hindi, or English stating:
     > *"ನಿಮ್ಮ ಒಟ್ಟು ಬಿಲ್ ₹237. ಬಿಡಿಭಾಗಗಳ ಎಂಆರ್‌ಪಿ ರಶೀದಿ ಪರಿಶೀಲಿಸಲಾಗಿದೆ. ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ಹಣ ನೀಡಬೇಡಿ."*
     > *(Your total bill is ₹237. Spare parts MRP receipt is verified. Do not pay any extra cash).*
   - The audio note removes friction, empowers non-literate and vernacular users, and establishes an auditable guarantee.

2. **The Gig Worker Dispatch Deficit ("Earnings Heatmap & High-Demand Hotspots")**:
   - Technicians on two-wheelers waste 20–35% of their daily fuel and time idling in low-demand pockets.
   - When rain, heat waves, or late-night power outages occur, demand surges in specific neighborhoods (e.g., Kuvempunagar, Vijayanagar, Indiranagar, Koramangala).
   - **Solution**: An interactive tactical Demand Hotspot Radar (`DemandHotspotRadarCard`) on the worker dashboard. It displays live neighborhood clusters with surge multipliers (+₹50 to +₹100 weekend/rain bonus), two-wheeler scooter ETA, and 1-tap turn-by-turn navigation via Google Maps.

---

## 2. Audio-Assisted Voice Briefing Architecture

### 2.1 Core Components
- **`VoiceBriefingService`** (`apps/mobile/lib/core/services/voice_briefing_service.dart`):
  - Singleton handling audio speech synthesis and playback state tracking (`idle`, `playing`, `paused`, `completed`).
  - Synthesizes localized spoken transcripts with currency formatting in Kannada, Hindi, and English.
  - Exposes an active subtitle stream (`activeTranscriptStream`) and playback state stream (`stateStream`) for synchronized UI animations.
- **`VoiceBriefingPill`** (`apps/mobile/lib/features/shared/widgets/voice_briefing_pill.dart`):
  - Interactive glassmorphic pill button displaying locale-sensitive prompts (e.g., `🔊 [ಕನ್ನಡದಲ್ಲಿ ಕೇಳಿ]` / `🔊 [ऑडियो में सुनें]`).
  - Animated 3-bar soundwave equalizer running during active audio playback.
  - Slide-in closed-caption transcript banner rendered directly beneath the pill for accessible multi-modal feedback.
- **Integration Points**:
  - `MaterialEscrowBillBreakdown` (checkout & invoice breakdowns).
  - `tracking_screen.dart` (doorstep spare parts approval banner & job completion invoice).

### 2.2 Trilingual Transcripts Matrix

| Language | Locale Code | Example Spoken Briefing |
| :--- | :--- | :--- |
| **Kannada** | `kn` | *"ನಿಮ್ಮ ಒಟ್ಟು ಬಿಲ್ ₹237. ಬಿಡಿಭಾಗಗಳ ಎಂಆರ್‌ಪಿ ರಶೀದಿ ಪರಿಶೀಲಿಸಲಾಗಿದೆ. ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ಹಣ ನೀಡಬೇಡಿ."* |
| **Hindi** | `hi` | *"आपका कुल बिल ₹237 है। स्पेयर पार्ट्स की एमआरपी रसीद सत्यापित है। कोई अतिरिक्त नकद न दें।"* |
| **English** | `en` | *"Your total bill is ₹237. Spare parts MRP receipt is verified. Do not pay any extra cash."* |

---

## 3. Worker Demand Radar & Hotspot Navigation

### 3.1 Domain Model & Scoring
- **`HighDemandZone`** (`apps/mobile/lib/core/models/high_demand_zone.dart`):
  - Coordinates (`latitude`, `longitude`), neighborhood identifier, localized display name (`Kuvempunagar`, `Vijayanagar`, `Gokulam`, etc.).
  - Surge tier classification: `moderate` (1.2x), `high` (1.5x), `extreme` (2.0x).
  - Real-time bonus payout (e.g., `+₹50 Weekend Rain Bonus`, `+₹75 Midnight Power Outage Bonus`).
  - Haversine distance calculations and two-wheeler speed estimation (average 25 km/h urban congested speed) to yield realistic scooter transit times (`🛵 4 mins (1.8 km)`).

### 3.2 Dispatch Engine
- **`DemandHotspotService`** (`apps/mobile/lib/core/services/demand_hotspot_service.dart`):
  - City cluster resolver supporting Mysuru and Bengaluru metros.
  - Computes nearby hotspots filtered within reachable radius (15 km) and sorted by surge bonus.
  - Launches native navigation (`geo:` or Google Maps intent `https://www.google.com/maps/dir/?api=1&destination=lat,lng`) with fallback deep links.

### 3.3 Dashboard Card Ergonomics
- **`DemandHotspotRadarCard`** (`apps/mobile/lib/features/worker/widgets/demand_hotspot_radar_card.dart`):
  - High-contrast tactical card with radar sweep animation and pulsating emerald/amber beacons.
  - Interactive horizontal zone selector chips showing demand intensity.
  - Prominent "Navigate to Hotspot" CTA with tactile haptic feedback.
  - Integrated into ROW 1.8 of `worker_home_screen.dart` with an accessible quick toggle pill in the header.

---

## 4. Verification & Automated Test Coverage

The suite in `test/voice_briefing_and_demand_radar_test.dart` validates:
1. Trilingual transcript generation across varied rupee amounts and spare parts statuses.
2. Singleton audio playback state lifecycle transitions (`idle` -> `playing` -> `completed`).
3. Closed-caption sync and stop invocation.
4. Haversine distance calculation and two-wheeler transit estimation.
5. High-demand zone filtering and surge tier classification.
6. `VoiceBriefingPill` widget rendering and tap interactions.
7. `DemandHotspotRadarCard` widget rendering, zone switching, and turn-by-turn navigation triggers.

---

## 5. Field Deployment Guidelines
1. **Device Speaker Fallbacks**: On devices without an active hardware TTS engine, `VoiceBriefingService` gracefully falls back to pre-recorded CDN audio snippets or text closed-caption display without throwing unhandled exceptions.
2. **Outdoor Sunlight Visibility**: In `DemandHotspotRadarCard`, text contrast exceeds WCAG AAA (7:1) using obsidian surfaces (`#070B14`) and luminous emerald (`#10B981`) and amber (`#F59E0B`) highlights for visibility under direct sunlight.
