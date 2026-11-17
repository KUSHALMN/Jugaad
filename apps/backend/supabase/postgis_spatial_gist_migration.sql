-- ============================================================================
-- Jugaad App — PostGIS Spatial GiST Index Migration
-- ============================================================================
-- Ensures PostGIS extension is active, location columns are properly typed as
-- GEOGRAPHY(POINT, 4326), and spatial GiST indexes are created for instant
-- nearest-worker radius queries (ST_DWithin / ST_Distance).
-- ============================================================================

-- 1. Ensure PostGIS extension is loaded
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Ensure worker table has location column and coordinate fallbacks
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS latitude FLOAT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS longitude FLOAT;

-- 3. Synchronize existing lat/long to geography location where missing
UPDATE public.workers
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE location IS NULL 
  AND latitude IS NOT NULL 
  AND longitude IS NOT NULL;

-- 4. GiST Spatial Index on workers.location (Primary Spatial Search)
CREATE INDEX IF NOT EXISTS idx_workers_location_gist 
  ON public.workers USING GIST(location);

-- 5. Filtered Spatial GiST Index for online & available workers
-- Maximizes index buffer cache hit ratio by only indexing workers eligible for dispatch
CREATE INDEX IF NOT EXISTS idx_workers_available_online_gist 
  ON public.workers USING GIST(location)
  WHERE is_available = true AND is_online = true;

-- 6. Filtered Spatial GiST Index for emergency dispatch
CREATE INDEX IF NOT EXISTS idx_workers_emergency_location_gist 
  ON public.workers USING GIST(location)
  WHERE is_available = true AND is_online = true AND emergency_available = true;

-- 7. Trigger to automatically keep `location` synchronized whenever latitude/longitude are updated
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
