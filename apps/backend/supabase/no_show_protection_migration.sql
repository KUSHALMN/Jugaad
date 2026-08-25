-- ============================================================================
-- Jugaad App — No-Show Protection (Antigravity) Database Migration
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ADD STRIKES AND SUSPENSION COLUMNS TO WORKERS
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE workers ADD COLUMN IF NOT EXISTS strikes INTEGER DEFAULT 0;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS last_strike_at TIMESTAMPTZ;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS suspended BOOLEAN DEFAULT false;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. ADD AGREED PRICE AND STATE TIMESTAMPS TO JOBS
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS agreed_price DECIMAL(10,2);
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS no_show_at TIMESTAMPTZ;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS pre_arrival_checked_at TIMESTAMPTZ;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS on_the_way_confirmed_at TIMESTAMPTZ;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. CREATE PRICE CHANGE REQUESTS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS price_change_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE NOT NULL,
  worker_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  old_price DECIMAL(10,2) NOT NULL,
  new_price DECIMAL(10,2) NOT NULL,
  reason TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookups on job_id
CREATE INDEX IF NOT EXISTS idx_price_change_requests_job ON price_change_requests(job_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. UPDATE search_nearby_workers RPC FOR ANTIGRAVITY STRIKE SYSTEM
-- ─────────────────────────────────────────────────────────────────────────────
-- Updates the PostGIS search:
--   - Excludes suspended workers (suspended = true OR strikes >= 3)
--   - Deprioritizes workers with 2 strikes (forces them to the bottom of the list)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION search_nearby_workers(
  user_lat    FLOAT,
  user_lng    FLOAT,
  radius_km   FLOAT,
  job_category TEXT,
  p_page      INT DEFAULT 0,
  p_limit     INT DEFAULT 10
)
RETURNS TABLE (
  id               VARCHAR,
  name             VARCHAR,
  phone            VARCHAR,
  skills           TEXT[],
  rating           FLOAT,
  distance_meters  FLOAT,
  is_available     BOOLEAN,
  profile_photo    VARCHAR,
  completed_jobs   INT,
  emergency_available BOOLEAN,
  total_count      INT
) LANGUAGE plpgsql
STABLE
PARALLEL SAFE
AS $$
DECLARE
  radius_m     FLOAT := radius_km * 1000.0;
  user_point   GEOGRAPHY := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::GEOGRAPHY;
  total_cnt    INT;
  safe_limit   INT := LEAST(GREATEST(p_limit, 1), 50);
  safe_page    INT := GREATEST(p_page, 0);
BEGIN
  -- ── Count total matching workers (for pagination metadata) ──
  SELECT COUNT(*)::INT INTO total_cnt
  FROM workers w
  WHERE w.is_available = true
    AND w.is_online = true
    AND w.location IS NOT NULL
    -- Strike/Suspension check: filter out suspended workers
    AND COALESCE(w.suspended, false) = false
    AND COALESCE(w.strikes, 0) < 3
    AND w.approval_status != 'suspended'
    AND (
      job_category IS NULL
      OR job_category = ''
      OR w.skills @> ARRAY[job_category]
    )
    AND ST_DWithin(w.location, user_point, radius_m);

  -- ── Return matching workers sorted by strike penalty, then distance ──
  RETURN QUERY
  SELECT
    w.id::VARCHAR,
    w.name::VARCHAR,
    w.phone::VARCHAR,
    w.skills::TEXT[],
    COALESCE(w.rating, 0.0)::FLOAT,
    ST_Distance(w.location, user_point)::FLOAT AS distance_meters,
    w.is_available::BOOLEAN,
    w.id_document_url::VARCHAR AS profile_photo,
    COALESCE(w.total_jobs, 0)::INT AS completed_jobs,
    COALESCE(w.emergency_available, false)::BOOLEAN,
    total_cnt
  FROM workers w
  WHERE w.is_available = true
    AND w.is_online = true
    AND w.location IS NOT NULL
    -- Strike/Suspension check: filter out suspended workers
    AND COALESCE(w.suspended, false) = false
    AND COALESCE(w.strikes, 0) < 3
    AND w.approval_status != 'suspended'
    AND (
      job_category IS NULL
      OR job_category = ''
      OR w.skills @> ARRAY[job_category]
    )
    AND ST_DWithin(w.location, user_point, radius_m)
  ORDER BY
    -- Deprioritize workers with 2 strikes: they go to the bottom of the list
    (CASE WHEN COALESCE(w.strikes, 0) >= 2 THEN 1 ELSE 0 END) ASC,
    distance_meters ASC
  LIMIT safe_limit
  OFFSET (safe_page * safe_limit);
END;
$$;

GRANT EXECUTE ON FUNCTION search_nearby_workers TO anon, authenticated, service_role;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC: get_job_coordinates
-- ─────────────────────────────────────────────────────────────────────────────
-- Helper to retrieve the raw latitude and longitude of a job from its PostGIS
-- geography column. Used by the backend during auto-reassignment.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_job_coordinates(p_job_id UUID)
RETURNS TABLE(lat FLOAT, lng FLOAT) LANGUAGE sql STABLE AS $$
  SELECT ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
  FROM jobs WHERE id = p_job_id;
$$;

GRANT EXECUTE ON FUNCTION get_job_coordinates TO anon, authenticated, service_role;

