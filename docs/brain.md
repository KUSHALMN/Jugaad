# Project Brain

## 1. Project Overview
* **Project Name**: Jugaad
* **Purpose**: Hyperlocal, on-demand blue-collar worker marketplace for Mysuru, India.
* **Vision**: Become the "Urban Company" for tier-2 and tier-3 cities.
* **Core Objectives**: High matching speed, provider verification safety, and transaction reliability.
* **Target Users**: Customers (Employers) booking trades, Workers (Providers) delivering services, and Admins.
* **Development Stage**: MVP integration, migration from Firestore mock to Supabase Cloud database.
* **High-Level Request Flow**: Client ➔ FastAPI Backend Gateway ➔ Supabase DB. Notifications push via FCM.

---

## 2. Current Development Status
* **Current Development Focus**: Worker verification, registration wizard status, and admin role enforcement.
* **Current Priorities**: Verification testing, end-to-end admin approvals validation.
* **Current Blockers**: None.
* **Recently Completed Work**:
  - Migrated worker approval/rejection mutations from client-side direct writes to secure backend endpoints.
  - Enabled push notifications to workers on status approval/rejection.
  - Updated configuration from a stale database to the active project (`ampsqwrdldvkldjwckrb`).
  - Implemented real-time streaming and filtering of approved/online workers in the User portal's Workers section with profile photo rendering, category badges, and category selection chips (Issue 5).
* **Upcoming Work**: Integrated payment checkout checks and WebSockets location channels.

---

## 3. Tech Stack
* **Backend**: FastAPI (Python 3.11+), Uvicorn.
* **Frontend**: Flutter Client App (Riverpod, GoRouter), React Admin dashboard (Vite, Tailwind CSS v4).
* **Database**: Supabase Cloud (PostgreSQL + PostGIS spatial extension).
* **Authentication**: Firebase Auth (Mobile/Web clients), Supabase Auth (Admin dashboard).
* **Caching**: Redis / Upstash Redis (rate limiting & query caching).
* **Notifications**: Firebase Cloud Messaging (FCM).
* **Payments**: Razorpay.
* **Testing**: Python verification scripts, dashboard compiler checks (`npm run build`).

---

## 4. Repository Map
* **Entry Points**:
  - `apps/backend/main.py`: Main backend server initialization.
  - `apps/mobile/lib/main.dart`: Main Flutter app entry point.
  - `apps/admin/src/main.jsx`: React admin panel entry.
* **Important Folders**:
  - `apps/backend/routers`: API endpoint definitions (workers, users, jobs, payments).
  - `apps/backend/services`: Integration service managers (FCM, Review, Payments).
  - `apps/backend/shared`: Global middleware (Auth, database connection pooling, logging config).
  - `apps/backend/supabase`: Postgres schema DDLs and SQL migration scripts.
* **Configurations**:
  - `apps/backend/.env` & `.env.local`: Environment secrets and configuration parameters.
  - `apps/admin/src/supabaseClient.js`: Client database initializer.

---

## 5. Architecture
* **System Design**: Stateless API gateways routing business-critical processes to internal microservice handlers.
* **Request Flow**: Clients invoke FastAPI Monolith. Monolith verifies session headers, runs database updates, dispatches FCM alerts, and responds.
* **Authentication Flow**:
  - Customers/Workers authenticate via Firebase Auth. Monolith parses and decrypts JWTs in `shared/auth.py`.
  - Admins authenticate via Supabase Auth. The dashboard passes the admin UID via `X-Admin-Id` header for backend security role validation.
* **Mobile Routing Flow**: GoRouter evaluates `redirect()` synchronously on every navigation event. `_AuthRefreshListenable` bridges Firebase Auth stream changes and Riverpod `authProvider` state changes into GoRouter's `refreshListenable`, ensuring the router re-evaluates when the user's role resolves from the database.
* **State Management**: React dashboard uses local hooks; Flutter app utilizes Riverpod provider caches.
* **Dependency Relationships**: Backend endpoints depend on `verify_firebase_token` or `verify_admin_user` injectables.
* **Error Handling**: FastAPI translates database exceptions into HTTPExceptions; dashboard UI alerts errors gracefully.

---

## 6. Architecture Decision Records (ADR)
### ADR-001: Backend-Mediated Worker Approvals
* **Decision**: Migrate worker approval/rejection mutations from client-side direct writes to secure backend API routes.
* **Reason**: Exposing database write access on worker validation fields directly to client dashboards bypasses security controls and compromises transaction safety.
* **Tradeoffs**: Minor increase in API call latency compared to direct writes.
* **Status**: Approved & Implemented.

### ADR-002: GoRouter-Riverpod Bridge via _AuthRefreshListenable
* **Decision**: Bridge Riverpod's `authProvider` state changes into GoRouter's `refreshListenable` by subscribing `_AuthRefreshListenable` to both Firebase Auth stream and Riverpod's `ProviderContainer.listen()`. Keep `redirect()` purely synchronous and side-effect-free.
* **Reason**: GoRouter only re-evaluates redirect guards when its `refreshListenable` fires. Without subscribing to Riverpod, GoRouter was unaware when the async Supabase role query completed, causing users to get stuck on splash/onboarding screens or triggering infinite redirect loops (`/onboarding => /auth/onboarding => /onboarding`).
* **Tradeoffs**: `ProviderContainer` reference is captured once during router initialization; the static singleton pattern means it cannot be swapped during hot-reload testing without a full restart.
* **Status**: Approved & Implemented.

---

## 7. Coding Standards
* **Python**: Standard PEP 8 rules. Async function declarations for IO-bound routes.
* **React/JSX**: Functional components, strict prop typing, utility classes via Tailwind.
* **Logging**: Structured logger tracking endpoint executions, database transaction status, and FCM outputs.

---

## 8. Project Rules
* Never write to worker verification status flags (`approval_status`, `id_verified`) directly from the frontend dashboard.
* Always check the active Supabase project reference (`ampsqwrdldvkldjwckrb`) before executing DB queries.
* Validate that geographical inputs represent logical coordinates.
* **GoRouter `redirect()` must be synchronous**: Never perform `await` calls, database queries, or network requests inside `redirect()`. All async state resolution must happen in the provider layer; the router reads provider state synchronously.
* **No side-effects in `redirect()`**: Do not call `modeProvider.setMode()` or any method that triggers `notifyListeners()` on the `refreshListenable` from inside `redirect()`, as this causes re-entrant redirect cycles.

---

## 9. Protected Components
* **Authentication Middleware (`shared/auth.py`)**: Cryptographic signature validation; critical to prevent unauthorized endpoint access.
* **Payment Gateways (`services/payment_service`)**: Integrates with third-party Razorpay. Must not change to protect transaction integrity.
* **PostGIS Database RPC Functions**: Underlying database routines (`approve_worker`, `reject_worker`, `find_nearby_workers`) must maintain signature parity.

---

## 10. Reusable Patterns
* **FastAPI Admin Role Verification**:
  Injected dependency matching the `X-Admin-Id` header against database user records.
* **PostGIS Auto-Radius Search**:
  Uber-style proximity query fallback (5km ➔ 10km) to ensure search results if local listings are empty.

---

## 11. Business Logic
* **Worker Lifecycle**: Wizard Registration ➔ Submitted (`pending`) ➔ Admin verification review ➔ Approved (`online`/`is_available`) or Rejected (`offline`).
* **Emergency Dispatch**: High-priority jobs route nearby matches using PostGIS spatial algorithms, triggering sound alerts.

---

## 12. Database
* **Project Reference**: `ampsqwrdldvkldjwckrb` (Supabase Cloud).
* **Tables**:
  - `public.users`: Firebase user mappings, role flags, and push token parameters.
  - `public.workers`: Trade-specific fields, location geometry, and verification attributes.
  - `public.jobs`: Connects employers, workers, status enums, and coordinates.
* **Storage Buckets**:
  - `worker-photos` (Public): Avatars and logos.
  - `worker-verification` (Private): Aadhaar card images (RLS restricted to admin reads).
* **RPC Functions**:
  - `approve_worker(p_worker_id)`: Atomically updates worker status to active.
  - `reject_worker(p_worker_id)`: Atomically rejects worker registration.
* **RLS Policies**: Admin role permissions enforce read controls on sensitive documents.

---

## 13. API
* **Version**: `/v1` and `/api/v1` prefixes.
* **Mutators**:
  - `POST /v1/workers/{worker_id}/approve`: Approves worker profile and triggers FCM.
  - `POST /v1/workers/{worker_id}/reject`: Rejects worker profile and triggers FCM.
* **Rate Limiting**: Clamped to 10 queries per minute per token via Redis.

---

## 14. Environment Variables
* `SUPABASE_URL`: Target project host path.
* `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY`: API authentication tokens.
* `REDIS_URL` / `UPSTASH_REDIS_REST_URL`: API caching endpoints.
* `GOOGLE_APPLICATION_CREDENTIALS`: Path to Firebase Service Account configuration.

---

## 15. External Services
* **Supabase Cloud**: Cloud relational database.
* **Firebase Cloud Messaging**: High-priority push alerts.
* **Razorpay Gateway**: External payment checkout engine.

---

## 16. Performance Notes
* PostgREST parses database structure on startup. Always run `NOTIFY pgrst, 'reload schema';` inside the SQL Editor after modifying table attributes or functions.
* Proximity searches are cached with a 30s TTL in Redis.

---

## 17. Security
* **Access Rules**: Sensitive columns (like approval status) are secured behind the FastAPI gateway.
* **File Protection**: Private verification document buckets restrict access to users with role = `admin`.
* **Input Sanitization**: Database inputs utilize query bindings to prevent SQL injections.

---

## 18. Commands
* **Run Backend API**:
  ```powershell
  .venv\Scripts\python.exe main.py
  ```
* **Run Admin Dashboard**:
  ```powershell
  npm run dev
  ```
* **Build Admin Dashboard**:
  ```powershell
  npm run build
  ```
* **Force Schema Cache Reload**:
  ```sql
  NOTIFY pgrst, 'reload schema';
  ```

---

## 19. Testing Strategy
* Run verification scripts (`test_db_connection.py`, `test_jobs_query.py`, `check_worker.py`) to confirm API integration.
* Executing `npm run build` in `jugaad-admin` ensures type safety and build validity.

---

## 20. Known Issues
* PostgREST API schema caches can fall out of sync with DDL modifications. Re-execute the schema reload NOTIFY query in the dashboard console.
* **GoRouter redirect loop (RESOLVED)**: After project restructuring, `/onboarding` was aliased to `/auth/onboarding` in the global redirect, but the role-null guard redirected back to `/onboarding`, creating an infinite loop. Root cause: GoRouter did not listen to Riverpod state changes, and `redirect()` contained async DB calls and side-effects. Fixed by bridging Riverpod into `refreshListenable` and making `redirect()` purely synchronous.

---

## 21. AI Working Instructions
* Before querying, check that the database URL points to project ref `ampsqwrdldvkldjwckrb`.
* Do not duplicate existing modules; inspect `shared/` and `services/` before declaring new controllers.
* Keep changes minimal, avoiding clean-code refactoring of stable systems.

---

## 22. AI Response Preferences
* Avoid adding empty configurations or dummy files.
* Prefer modifying current endpoint files rather than introducing extra layers of abstraction.
* Provide direct fixes instead of mock placeholders.

---

## 23. AI Pitfalls
* Do NOT change database column schemas without reviewing existing postgrest spec configurations.
* Do NOT modify existing RPC signature argument shapes.
* Do NOT bypass admin headers role checks.

---

## 24. Common Mistakes
* **Misidentifying Database Instances**: Running SQL migrations on a stale database project (e.g. `vvgwpjmatmekukecnwln`). Always verify the active project URL matches `ampsqwrdldvkldjwckrb`.

---

## 25. Glossary
* **Worker**: Service provider delivering trade skills.
* **Employer**: Customer posting service bookings.
* **Pending**: Initial state of worker profiles awaiting admin approval.
* **Approved**: Worker profile verified; status turns to online and available.
* **Heartbeat**: Periodic GPS location reports verifying active workers.

---

## 26. Feature Memory
* **Worker Approval Transitions (Issue 4)**:
  - *Purpose*: Implements backend validation endpoints allowing administrators to change applicant status atomically and send confirmation FCMs.
  - *Files*: `apps/backend/services/fcm_service.py`, `apps/backend/routers/workers.py`, `apps/admin/src/JugaadOpsDashboard.jsx`.
* **Approved/Online Workers Real-time List (Issue 5)**:
  - *Purpose*: Renders approved and online workers in the User portal's Workers section in real time, supporting category ChoiceChips filtering, profile photo rendering with initials fallback, work category badge, and online status indicator.
  - *Files*: `apps/mobile/lib/features/user/screens/worker_list_screen.dart`.
* **GoRouter Redirect Loop Fix (Issue 6)**:
  - *Purpose*: Eliminated `GoException: redirect loop detected /onboarding => /auth/onboarding => /onboarding` by bridging Riverpod's `authProvider` into GoRouter's `refreshListenable` via `_AuthRefreshListenable`, making `redirect()` synchronous and side-effect-free, and routing directly to final paths (`/worker/home`, `/user/home`) instead of alias paths.
  - *Files*: `apps/mobile/lib/app.dart`, `apps/mobile/lib/main.dart`, `apps/mobile/lib/core/providers/auth_provider.dart`.

---

## 27. Recent Changes
* **2026-06-27**: Implemented a structured role-based routing flow (Steps 1-6). Configured `AuthNotifier` in `auth_provider.dart` to hold `isLoading: true` and block emitting the logged-in `uid` until the user's role is fully resolved from the database, eliminating auth race conditions. Refactored the GoRouter `redirect` guard in `app.dart` to strictly inspect this role state, handle registration paths for new workers, redirect workers to `/worker/home`, and user roles to `/user/home` depending on their mode, with comprehensive debug logging. Added `setModeWithoutNotify` to `PortalModeProvider` to allow silent theme updates of `PortalMode` during redirect evaluation, preventing recursive redirect build loops.
* **2026-06-27**: Fixed the role portal switching and registration routing bugs. Refactored GoRouter's route protection guards in `app.dart` to route based on active `modeProvider.mode` and worker registration status (`role == 'worker'`). This ensures users who log in as workers are guided to the registration wizard (`/worker/register/*`) if they aren't registered yet, instead of being incorrectly booted to `/user/home` by the strict user-role guard. It also cleanly locks registered workers in their active portal mode (User or Worker).
* **2026-06-27**: Prevented Web startup hangs by refactoring `main.dart` to initialize non-critical background services (`LocationService`, `NotificationService`, and `HeartbeatService`) asynchronously. Unblocked `runApp()` execution by removing blocking `await` statements from services that require user interaction (e.g. browser GPS or push notification permission dialogs).
* **2026-06-27**: Resolved the browser refresh loading issues on Web by implementing a custom, light-themed HTML boot loader spinner in `index.html` with a MutationObserver to fade out/remove the loader once the Flutter canvas elements mount. Switched the `SplashScreen` animation to a premium light theme with dark slate/gray text and adjusted animation timings (saving 7.5 seconds of splash screen lock time).
* **2026-06-27**: Fixed GoRouter redirect loop (`/onboarding => /auth/onboarding => /onboarding`) by bridging Riverpod `authProvider` into GoRouter's `refreshListenable` via `_AuthRefreshListenable`. Made `redirect()` fully synchronous — removed all `await` calls, database queries, and `modeProvider.setMode()` side-effects. Replaced alias paths (`/worker/dashboard`, `/home`) with final resolved paths (`/worker/home`, `/user/home`) to eliminate double-redirect overhead. Passed `ProviderContainer` from `main.dart` into `AppRouter.getRouter()` for closure capture.
* **2026-06-26**: Structured repository layout into standard monorepo structure (`apps/`, `docs/`, `infrastructure/`, `scripts/`).
* **2026-06-26**: Implemented real-time streaming, status indicators, profile photos, category badges, and category filter chips in the User portal's Workers list (Issue 5).
* **2026-06-26**: Unified backend endpoints by refactoring Render microservices to import directly from monolith routing definitions folder.
* **2026-06-26**: Modified admin dashboard to call backend mutation endpoints.
* **2026-06-26**: Switched database environment configs to active project ref `ampsqwrdldvkldjwckrb`.
* **2026-06-26**: Created transactional database functions (`approve_worker`/`reject_worker`).
* **2026-06-26**: Fixed Admin dashboard navbar conditional rendering to support view switching.
* **2026-06-26**: Redesigned Admin dashboard login page to a 65/35 split light theme layout with a generated worker hero image.
* **2026-06-26**: Initialized admin telemetry dashboard stats to 0 instead of dummy data to ensure only real production metrics are displayed.
* **2026-06-26**: Completely redesigned the Admin Dashboard UI using a premium design system.
* **2026-06-26**: Synchronized the "Operations" panel settings in the Admin Dashboard with the live platform. Created a single-row `platform_config` table in Supabase. Built `GET /v1/platform/config` and `PUT /v1/platform/config` backend endpoints in `main.py`. Updated Flutter Mobile Apps to replace hardcoded surge fees (₹150) with dynamically fetched values from the backend via a new `PlatformConfigService`. Updated the backend spatial worker search to use dynamic dispatch radius values set by the admin instead of hardcoded 5km/10km constants.

---

## 28. Decision Log
* **2026-06-27**: GoRouter `redirect()` must never perform async work or trigger `notifyListeners()` on its own `refreshListenable`. The correct pattern is to bridge Riverpod state changes into GoRouter via `ProviderContainer.listen()` inside a custom `ChangeNotifier`, and keep `redirect()` as a pure synchronous state evaluator.
* **2026-06-27**: `ProviderContainer` is passed as a constructor parameter to `_AuthRefreshListenable` and captured in the `getRouter()` closure, avoiding `ProviderScope.containerOf(context)` tree-walks inside `redirect()` for both correctness and performance.
* **2026-06-26**: Restructured codebase to standard monorepo layout to optimize project borders, document paths, and startup scripts.
* **2026-06-26**: Utilized local availability filtering on top of status='approved' streaming to overcome single-column filter limitations of Supabase stream builders in Flutter Dart SDK.
* **2026-06-26**: Backend validation of worker status updates to secure the data model against client-side tampering.
* **2026-06-26**: Switched target project reference to `ampsqwrdldvkldjwckrb`.
* **2026-06-26**: Adopted a split-screen layout (65% visual, 35% form) for the admin authentication page to provide a more professional and modern enterprise look.
* **2026-06-26**: Refactored the dashboard's navigation to be responsive, displaying inline tabs in the top header on desktop and a fixed bottom tab bar on mobile. Replaced empty placeholder views with fully populated tables and interactive operations widgets (like Twilio simulator) to make the panel feel like a complete production-ready administrative command console.
* **2026-06-26**: Implemented global platform configuration settings via a single-row `platform_config` table rather than using environment variables, enabling administrators to adjust surge pricing, dispatch boundaries, and SMS routing in real-time through the frontend UI without requiring backend redeploys.

---

## 29. Active TODO
* **Priority 1**: Test and debug heartbeat monitor loops.
* **Priority 2**: Configure test verification parameters for Razorpay webhook endpoints.

---

## 30. Future Roadmap
* **High**: Dynamic real-time worker tracking map displays.
* **Medium**: SMS status updates.

---

## 31. Quick Reference
* **FastAPI Gateway URL**: `http://localhost:8000`
* **React Dashboard URL**: `http://localhost:5173`
* **Schema reload statement**: `NOTIFY pgrst, 'reload schema';`
* **Backend Cwd**: `apps/backend`
* **Admin dashboard Cwd**: `apps/admin`
* **Mobile Cwd**: `apps/mobile`
