-- ============================================================================
-- Jugaad App — Unified Production Backend Improvements Migration
-- ============================================================================
-- Combines:
--   1. PostGIS Spatial GiST indexing & coordinates sync trigger
--   2. High-concurrency composite indexes (jobs, users, workers, reviews)
--   3. Optimized get_nearby_workers RPC with ST_DWithin and p_is_emergency
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: POSTGIS SPATIAL GIST INDEXING
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS latitude FLOAT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS longitude FLOAT;

-- Backfill missing location from lat/lng
UPDATE public.workers
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE location IS NULL 
  AND latitude IS NOT NULL 
  AND longitude IS NOT NULL;

-- Spatial GiST indexes
CREATE INDEX IF NOT EXISTS idx_workers_location_gist 
  ON public.workers USING GIST(location);

CREATE INDEX IF NOT EXISTS idx_workers_available_online_gist 
  ON public.workers USING GIST(location)
  WHERE is_available = true AND is_online = true;

CREATE INDEX IF NOT EXISTS idx_workers_emergency_location_gist 
  ON public.workers USING GIST(location)
  WHERE is_available = true AND is_online = true AND emergency_available = true;

-- Auto-sync trigger for lat/lng to geography location
CREATE OR REPLACE FUNCTION public.sync_worker_location_from_coords()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_worker_location ON public.workers;
CREATE TRIGGER trg_sync_worker_location
    BEFORE INSERT OR UPDATE OF latitude, longitude
    ON public.workers
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_worker_location_from_coords();

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: HIGH-CONCURRENCY COMPOSITE INDEXES
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_jobs_employer_status 
  ON public.jobs (employer_id, status);

CREATE INDEX IF NOT EXISTS idx_jobs_worker_status 
  ON public.jobs (worker_id, status);

CREATE INDEX IF NOT EXISTS idx_jobs_status_created_at_desc 
  ON public.jobs (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_jobs_payment_status 
  ON public.jobs (payment_status, status);

CREATE INDEX IF NOT EXISTS idx_jobs_razorpay_order_id 
  ON public.jobs (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid 
  ON public.users (firebase_uid);

CREATE INDEX IF NOT EXISTS idx_users_phone 
  ON public.users (phone);

CREATE INDEX IF NOT EXISTS idx_workers_category_online_avail 
  ON public.workers (category, is_online, is_available);

CREATE INDEX IF NOT EXISTS idx_workers_phone 
  ON public.workers (phone);

CREATE INDEX IF NOT EXISTS idx_reviews_worker_id_rating 
  ON public.reviews (worker_id, rating);

CREATE INDEX IF NOT EXISTS idx_price_change_requests_job_status 
  ON public.price_change_requests (job_id, status);

CREATE INDEX IF NOT EXISTS idx_spare_parts_job_status 
  ON public.spare_parts (job_id, status);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: OPTIMIZED HYPERLOCAL DISPATCH RPC (get_nearby_workers)
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_nearby_workers(FLOAT, FLOAT, FLOAT, TEXT, TEXT[], BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS public.get_nearby_workers(FLOAT, FLOAT, FLOAT, TEXT, TEXT[]) CASCADE;

CREATE OR REPLACE FUNCTION public.get_nearby_workers(
    user_lat FLOAT,
    user_lng FLOAT,
    radius_meters FLOAT,
    service_type TEXT,
    exclude_worker_ids TEXT[] DEFAULT ARRAY['none'],
    p_is_emergency BOOLEAN DEFAULT false
)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    phone TEXT,
    rating FLOAT,
    service_types TEXT[],
    fcm_token TEXT,
    distance_meters FLOAT
) AS $$
DECLARE
    user_geom GEOGRAPHY;
BEGIN
    user_geom := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography;

    RETURN QUERY
    SELECT 
        w.id::TEXT,
        w.name::TEXT,
        w.phone::TEXT,
        COALESCE(w.rating, 5.0)::FLOAT,
        COALESCE(w.skills, ARRAY[COALESCE(w.category, '')])::TEXT[],
        COALESCE(w.fcm_token, u.fcm_token, '')::TEXT as fcm_token,
        ST_Distance(w.location, user_geom)::FLOAT as distance_meters
    FROM public.workers w
    LEFT JOIN public.users u ON (u.id = w.id OR u.firebase_uid = w.id)
    WHERE 
        COALESCE(w.is_online, true) = true
        AND COALESCE(w.is_available, true) = true
        AND (
            service_type IS NULL 
            OR service_type = '' 
            OR w.category ILIKE service_type
            OR w.skills @> ARRAY[service_type]
        )
        AND w.id::TEXT != ALL(exclude_worker_ids)
        AND (NOT p_is_emergency OR COALESCE(w.emergency_available, false) = true)
        AND w.location IS NOT NULL
        AND ST_DWithin(w.location, user_geom, radius_meters)
    ORDER BY distance_meters ASC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;
