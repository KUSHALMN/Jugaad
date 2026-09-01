# Changelog

All notable changes to the **Jugaad** platform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
