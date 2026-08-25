-- ============================================================================
-- Jugaad App — Emergency Worker Platform Migration
-- ============================================================================

-- 1. Alter Table: jobs (add emergency fields)
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS job_type VARCHAR(20) DEFAULT 'normal';
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS service_fee_type VARCHAR(20) DEFAULT 'normal';
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS surcharge_amount DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Alter Table: workers (add availability status & verification fields)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS emergency_available BOOLEAN DEFAULT false;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT false;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS identity_verified BOOLEAN DEFAULT false;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS skill_verified BOOLEAN DEFAULT false;

-- 3. Recreate View: worker_profiles (include emergency and verification fields)
DROP VIEW IF EXISTS worker_profiles CASCADE;

CREATE OR REPLACE VIEW worker_profiles AS
SELECT 
  id,
  name,
  phone,
  skills AS service_types,
  rating,
  total_jobs AS completed_jobs,
  is_available,
  id_document_url AS profile_photo,
  is_online,
  location::geometry AS current_location,
  emergency_available,
  phone_verified,
  identity_verified,
  skill_verified
FROM workers;

-- 4. Recreate Function: get_nearby_workers (support emergency matching filter)
DROP FUNCTION IF EXISTS get_nearby_workers(FLOAT, FLOAT, FLOAT, TEXT, TEXT[]) CASCADE;

CREATE OR REPLACE FUNCTION get_nearby_workers(
    user_lat FLOAT,
    user_lng FLOAT,
    radius_meters FLOAT,
    service_type TEXT,
    exclude_worker_ids TEXT[] DEFAULT ARRAY['none'],
    p_is_emergency BOOLEAN DEFAULT false
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
        wp.id::UUID,
        wp.name::TEXT,
        wp.phone::TEXT,
        COALESCE(wp.rating, 0.0)::FLOAT,
        wp.service_types::TEXT[],
        wt.token::TEXT as fcm_token,
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
        AND (NOT p_is_emergency OR wp.emergency_available = true)
        AND ST_DWithin(
            wp.current_location::geography,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
            radius_meters
        )
    ORDER BY distance_meters ASC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 4b. Recreate Function: search_workers_postgis (re-registered because worker_profiles was dropped)
DROP FUNCTION IF EXISTS search_workers_postgis(FLOAT, FLOAT, FLOAT, TEXT, INT, INT) CASCADE;

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

-- 5. Recreate Function: accept_job_atomic (record accepted_at timestamp)
DROP FUNCTION IF EXISTS accept_job_atomic(UUID, VARCHAR) CASCADE;

CREATE OR REPLACE FUNCTION accept_job_atomic(p_job_id UUID, p_worker_id VARCHAR(128))
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  v_employer_id VARCHAR(128);
BEGIN
  -- Retrieve employer_id from the job
  SELECT employer_id INTO v_employer_id FROM jobs WHERE id = p_job_id AND status IN ('open', 'matched', 'searching');
  
  IF v_employer_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Update job status, assign worker, set accepted_at, and increment version
  UPDATE jobs SET 
    status = 'accepted', 
    worker_id = p_worker_id, 
    version = version + 1, 
    updated_at = NOW(),
    accepted_at = NOW()
  WHERE id = p_job_id AND status IN ('open', 'matched', 'searching');

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  UPDATE workers SET is_available = false WHERE id = p_worker_id;

  -- Insert the matching booking record
  INSERT INTO bookings (job_id, worker_id, employer_id, status)
  VALUES (p_job_id, p_worker_id, v_employer_id, 'accepted');

  -- Trigger outbox event (pg_net trigger fires automatically)
  INSERT INTO outbox_events(job_id, event_type, payload)
  VALUES (p_job_id, 'JOB_ASSIGNED', jsonb_build_object('job_id', p_job_id::text, 'worker_id', p_worker_id::text));

  RETURN TRUE;
END;
$$;

-- 6. Add Performance Indexes for emergency lookups
CREATE INDEX IF NOT EXISTS idx_workers_emergency_available ON workers(emergency_available) WHERE is_online = true AND is_available = true;
CREATE INDEX IF NOT EXISTS idx_jobs_job_type_status ON jobs(job_type, status);
