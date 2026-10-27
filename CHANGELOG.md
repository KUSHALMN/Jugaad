# Changelog

All notable changes to the **Jugaad** platform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.5.0] - 2026-10-27
### Fixed
- **Google Play Services OAuth Certificate Alignment**: Configured Android Gradle `debug` build type to sign with production release keystore (`jugaad-release-key.jks`) matching registered Firebase / Google Cloud SHA-1 and SHA-256 fingerprints, eliminating `ApiException: 10`.
- **ProGuard / R8 Obfuscation Rules**: Added keep rules for `com.google.android.gms.auth.api.**` and `signin.**` preventing minification stripping during production builds.
- **Client Auth Flow Hardening**: Added explicit `email` and `profile` OAuth scopes, session cleanup with `signOut()` before login, and strict token presence assertions in `AuthService`.
- **Mobile UI Alignment & Center Brand Lockup**: Restructured top app bar using centered `Stack` on `LoginScreen` and `RoleSelectScreen` to prevent asymmetric shifts caused by `spaceBetween`.
- **Responsive Headlines & Non-Breaking Typography**: Adapted auth headlines to scale down smoothly on mobile screens with non-breaking `WidgetSpan` brand lockup preventing "Jugaad" from breaking across lines.
- **Trust Shield Vertical Alignment**: Restructured mobile trust props into a unified container with `Expanded` text columns, ensuring all category icons vertically align.
- **Worker Bottom Navigation Labels**: Added missing text labels and micro-indicators to Worker portal bottom navigation bar tabs.
- **Onboarding Signature Branding**: Updated onboarding header to use signature dual-color `JUG`/`AAD` brand typography.
- **Backend Tracking Telemetry Bounds**: Added strict latitude/longitude boundary checks (`-90..90`, `-180..180`) on public live worker telemetry polling.

---

## [1.4.0] - 2026-09-17
### Added
- **Multi-City & Division Geospatial Registry**: Comprehensive division-level bounding boxes and centroids for all divisions of Mysuru, Bengaluru, Mandya, Hassan, Hubli-Dharwad, Mangaluru, and dynamic upcoming expansion cities.
- **Citywide High-Rated Fallback Engine**: When no workers are available in a local neighborhood/division, the search engine automatically surfaces verified top-rated specialists (sorted by rating DESC, total completed jobs DESC) across the entire city.
- **Customer Region Busy Advisory**: Dynamic advisory messaging alerting customers when workers in their division are busy and enabling direct booking of top-rated citywide specialists.
- **Flutter UI Banners & Badges**: Integrated high-demand region advisory cards and "Top-Rated" badges across `WorkerSearchScreen`, `MatchingScreen`, and `WorkerListScreen`.
- **Automated Test Suite**: 7 comprehensive test suites in `test_universal_search_engine.py` validating division resolution, fallback contracts, and customer advisory messaging.

---

## [1.3.0] - 2026-09-01
### Added
- Response-level GZip compression (`GZipMiddleware`) for FastAPI responses reducing mobile payload sizes by 60–80%.
- In-memory TTL caching with write-through invalidation for service catalogs and platform configurations.
- Vite 8 / Rolldown manual chunk splitting for vendor modules (React, Supabase, Lucide) for optimal dashboard caching.
- Android JVM `largeHeap` configuration to eliminate OOM risks during media decoding.

### Fixed & Optimized
- Eliminated 60 FPS root-level widget rebuilds on `UserHomeScreen` and `WorkerHomeScreen` by isolating typewriter & particle animation timers into self-contained `RepaintBoundary` widgets.
- Resolved memory leaks and ticker lifecycle leaks across `MatchingScreen`, `TrackingScreen`, and `ActiveJobScreen` with full `dispose()` implementations.
- Implemented `BouncingScrollPhysics` and `cacheExtent: 500.0` with `RepaintBoundary` on `ServicesGridScreen` and `WorkerSearchScreen` for buttery 60/120Hz scrolling.

---

## [1.2.0] - 2026-08-26
### Added
- Comprehensive multi-portal documentation in `README.md` for User, Worker, and Admin systems.
- Docker containerization support for all 9 backend microservices.
- Multi-stage GitHub Actions CI/CD pipeline with build and code validation.
- Live platform configuration endpoints (`/v1/platform/config`) for dynamic surge fees and dispatch radius.

### Fixed
- Replaced client-side worker approval direct mutations with secure backend endpoints (`/v1/workers/{id}/approve`).
- Synchronous GoRouter redirect bridging with Riverpod `_AuthRefreshListenable` to eliminate redirect cycles.
- Flutter Web canvas bootloader with instant fadeout and dark/light splash screen animation timings.

---

## [1.1.0] - 2026-06-26
### Added
- Real-time online worker streaming in User Portal with dynamic category chips.
- Worker KYC 3-step registration wizard with Aadhaar image upload and verification queue.
- React Admin Operations Console with live KPI telemetry and KYC document review.

---

## [1.0.0] - 2026-05-23
### Added
- Initial release of Jugaad Hyperlocal Platform.
- PostGIS spatial radius queries for fast local worker matching.
- Firebase Authentication and Razorpay payment gateway integration.
