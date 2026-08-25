-- ============================================================================
-- Jugaad App — Worker Search PostGIS & Schema Alignment Migration
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ampsqwrdldvkldjwckrb/sql/new)
-- ============================================================================

-- 1. Enable PostGIS Extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Create worker_profiles view mapping workers table columns to the search schema
-- Explicitly cast location to geometry type to satisfy the geometry constraint
CREATE OR REPLACE VIEW worker_profiles AS
SELECT 
  id,
  name,
  skills AS service_types,
  rating,
  total_jobs AS completed_jobs,
  is_available,
  id_document_url AS profile_photo,
  is_online,
  location::geometry AS current_location
FROM workers;

-- 3. Create the worker search PostGIS RPC function
CREATE OR REPLACE FUNCTION search_workers_postgis(
  lat FLOAT,
  lng FLOAT,
  radius_km FLOAT,
  service_type TEXT,
  page INT,
  "limit" INT
)
RETURNS TABLE (
  id VARCHAR,
  name VARCHAR,
  service_types TEXT[],
  rating FLOAT,
  distance_meters FLOAT,
  is_available BOOLEAN,
  profile_photo VARCHAR,
  completed_jobs INT,
  total_count INT
) LANGUAGE plpgsql AS $$
DECLARE
  total_cnt INT;
BEGIN
  -- Get total count of matching workers matching the filters
  SELECT COUNT(*)::INT INTO total_cnt
  FROM worker_profiles wp
  WHERE wp.is_online = true
    AND wp.is_available = true
    AND (service_type IS NULL OR service_type = '' OR wp.service_types @> ARRAY[service_type])
    AND ST_DWithin(
          wp.current_location::geography,
          ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
          radius_km * 1000
        );

  RETURN QUERY
  SELECT 
    wp.id::VARCHAR, 
    wp.name::VARCHAR, 
    wp.service_types::TEXT[], 
    COALESCE(wp.rating, 0.0)::FLOAT as rating,
    ST_Distance(
      wp.current_location::geography,
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
    )::FLOAT as distance_meters,
    wp.is_available::BOOLEAN,
    wp.profile_photo::VARCHAR,
    COALESCE(wp.completed_jobs, 0)::INT as completed_jobs,
    total_cnt
  FROM worker_profiles wp
  WHERE wp.is_online = true
    AND wp.is_available = true
    AND (service_type IS NULL OR service_type = '' OR wp.service_types @> ARRAY[service_type])
    AND ST_DWithin(
          wp.current_location::geography,
          ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
          radius_km * 1000
        )
  ORDER BY distance_meters ASC
  LIMIT "limit" OFFSET (page * "limit");
END;
$$;

-- 4. Enable Realtime on the jobs table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'jobs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    CREATE PUBLICATION supabase_realtime;
    ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
END $$;

-- 5. Create Performance Indexes for search and matching
-- Index on workers for online and availability status
CREATE INDEX IF NOT EXISTS idx_workers_online_available ON workers(is_online, is_available);

-- Indexes on jobs for tracking status per user (employer) and worker
CREATE INDEX IF NOT EXISTS idx_jobs_employer_status ON jobs(employer_id, status);
CREATE INDEX IF NOT EXISTS idx_jobs_worker_status ON jobs(worker_id, status);
