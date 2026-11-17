-- ============================================================================
-- Jugaad App — Optimized Hyperlocal Dispatch RPC (PostGIS GiST)
-- ============================================================================
-- Replaces get_nearby_workers with an index-optimized PostGIS implementation.
-- Precomputes the user geography point once, leverages idx_workers_location_gist
-- with ST_DWithin for spherical meter queries, and sorts strictly by distance.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

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
    -- Construct spherical geography point once for entire scan
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
