# 🗄️ Supabase PostgreSQL Database Schema

This document outlines the core tables, foreign key constraints, RLS policies, and PostGIS RPC functions in the Jugaad platform.

---

## 1. Tables Overview

### `public.users`
- `id` (UUID, Primary Key)
- `firebase_uid` (Text, Unique, Indexed)
- `full_name` (Text)
- `phone` (Text)
- `role` (Text, Check: `role IN ('user', 'worker', 'admin')`)
- `fcm_token` (Text)
- `created_at` (Timestamp with timezone)

### `public.workers`
- `id` (UUID, Primary Key)
- `user_id` (UUID, FK -> `users.id`)
- `category` (Text, e.g., `electrician`, `plumber`)
- `location` (Geography Point, 4326)
- `approval_status` (Text, Default: `'pending'`)
- `is_available` (Boolean, Default: `true`)
- `is_online` (Boolean, Default: `false`)
- `rating` (Float, Default: `5.0`)
- `total_jobs_completed` (Integer, Default: `0`)
- `hourly_rate` (Float)
- `aadhaar_url` (Text)

### `public.jobs`
- `id` (UUID, Primary Key)
- `user_id` (UUID, FK -> `users.id`)
- `worker_id` (UUID, Nullable, FK -> `workers.id`)
- `category` (Text)
- `status` (Text, `pending | assigned | en_route | in_progress | completed | cancelled`)
- `location` (Geography Point, 4326)
- `address_text` (Text)
- `total_amount` (Float)
- `otp_code` (Text)

### `public.platform_config`
- `id` (Integer, Primary Key)
- `emergency_dispatch_radius_km` (Float)
- `surge_fee` (Float)
- `commission_percent` (Float)
- `updated_at` (Timestamp with timezone)

---

## 2. RPC Functions
- `approve_worker(p_worker_id UUID)`: Atomically transitions worker to `approved`.
- `reject_worker(p_worker_id UUID)`: Atomically transitions worker to `rejected`.
- `find_nearby_workers(p_lat Float, p_lng Float, p_radius_km Float, p_category Text)`: PostGIS spatial lookup.
