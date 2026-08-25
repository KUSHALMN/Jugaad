-- 1. Ensure required columns exist on workers table
ALTER TABLE workers ADD COLUMN IF NOT EXISTS work_category VARCHAR(100);
ALTER TABLE workers ADD COLUMN IF NOT EXISTS city VARCHAR(100) DEFAULT 'Mysuru';
ALTER TABLE workers ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS total_completed_jobs INTEGER DEFAULT 0;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true;

-- Backfill total_completed_jobs from total_jobs or totalJobsCompleted if 0
UPDATE workers SET total_completed_jobs = COALESCE(total_jobs, "totalJobsCompleted", 0) WHERE total_completed_jobs IS NULL OR total_completed_jobs = 0;
UPDATE workers SET is_verified = COALESCE("isVerified", id_verified, true) WHERE is_verified IS NULL;
UPDATE workers SET city = 'Mysuru' WHERE city IS NULL;
UPDATE workers SET is_active = true WHERE is_active IS NULL;

-- Backfill work_category from first skill if null
UPDATE workers SET work_category = skills[1] WHERE (work_category IS NULL OR work_category = '') AND array_length(skills, 1) > 0;

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_workers_location ON workers USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_workers_category_city ON workers (work_category, city, is_active, is_available);

-- 3. RPC function for Nearest Worker Search (Priority 1)
CREATE OR REPLACE FUNCTION search_workers_nearby(
  p_category TEXT,
  p_lat FLOAT,
  p_lng FLOAT,
  p_radius_m FLOAT
)
RETURNS TABLE (
  id VARCHAR,
  name VARCHAR,
  category VARCHAR,
  rating FLOAT,
  total_completed_jobs INT,
  is_verified BOOLEAN,
  distance_m FLOAT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    w.id::VARCHAR,
    COALESCE(w.name, 'Worker')::VARCHAR,
    COALESCE(w.work_category, p_category)::VARCHAR AS category,
    COALESCE(w.rating, 0.0)::FLOAT,
    COALESCE(w.total_completed_jobs, w.total_jobs, 0)::INT AS total_completed_jobs,
    COALESCE(w.is_verified, w."isVerified", w.id_verified, true)::BOOLEAN AS is_verified,
    ST_Distance(
      w.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    )::FLOAT AS distance_m
  FROM workers w
  WHERE (
      w.work_category = p_category 
      OR p_category = ANY(w.skills) 
      OR p_category = ANY(w.specialities)
      OR LOWER(w.work_category) = LOWER(p_category)
      OR LOWER(p_category) = ANY(SELECT LOWER(s) FROM unnest(w.skills) s)
    )
    AND COALESCE(w.is_active, true) = true
    AND COALESCE(w.is_available, true) = true
    AND ST_DWithin(
      w.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_m
    )
  ORDER BY distance_m ASC
  LIMIT 20;
END;
$$;

-- 4. RPC function for City-wide Rating Fallback Search (Priority 2/3)
CREATE OR REPLACE FUNCTION search_workers_citywide(
  p_category TEXT,
  p_city TEXT DEFAULT 'Mysuru'
)
RETURNS TABLE (
  id VARCHAR,
  name VARCHAR,
  category VARCHAR,
  rating FLOAT,
  total_completed_jobs INT,
  is_verified BOOLEAN,
  distance_m FLOAT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    w.id::VARCHAR,
    COALESCE(w.name, 'Worker')::VARCHAR,
    COALESCE(w.work_category, p_category)::VARCHAR AS category,
    COALESCE(w.rating, 0.0)::FLOAT,
    COALESCE(w.total_completed_jobs, w.total_jobs, 0)::INT AS total_completed_jobs,
    COALESCE(w.is_verified, w."isVerified", w.id_verified, true)::BOOLEAN AS is_verified,
    -1.0::FLOAT AS distance_m
  FROM workers w
  WHERE (
      w.work_category = p_category 
      OR p_category = ANY(w.skills) 
      OR p_category = ANY(w.specialities)
      OR LOWER(w.work_category) = LOWER(p_category)
      OR LOWER(p_category) = ANY(SELECT LOWER(s) FROM unnest(w.skills) s)
    )
    AND COALESCE(w.is_active, true) = true
    AND COALESCE(w.is_available, true) = true
    AND (
      w.city = p_city 
      OR w.area ILIKE '%' || p_city || '%'
      OR w.city IS NULL
    )
  ORDER BY 
    COALESCE(w.rating, 0.0) DESC, 
    COALESCE(w.total_completed_jobs, w.total_jobs, 0) DESC, 
    COALESCE(w.is_verified, w."isVerified", w.id_verified, true) DESC
  LIMIT 20;
END;
$$;
