
-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Nearby workers function
CREATE OR REPLACE FUNCTION get_nearby_workers(
    user_lat FLOAT,
    user_lng FLOAT,
    radius_meters FLOAT,
    service_type TEXT,
    exclude_worker_ids TEXT[] DEFAULT ARRAY['none']
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    phone TEXT,
    rating FLOAT,
    service_types TEXT[],
    fcm_token TEXT,
    distance_meters FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wp.id,
        wp.name,
        wp.phone,
        COALESCE(wp.rating, 0.0)::FLOAT,
        wp.service_types,
        wt.token as fcm_token,
        ST_Distance(
            wp.current_location::geography,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
        )::FLOAT as distance_meters
    FROM worker_profiles wp
    LEFT JOIN worker_fcm_tokens wt ON wt.worker_id = wp.id
    WHERE 
        wp.is_online = true
        AND wp.is_available = true
        AND wp.service_types @> ARRAY[service_type]
        AND wp.id::TEXT != ALL(exclude_worker_ids)
        AND ST_DWithin(
            wp.current_location::geography,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
            radius_meters
        )
    ORDER BY distance_meters ASC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;
