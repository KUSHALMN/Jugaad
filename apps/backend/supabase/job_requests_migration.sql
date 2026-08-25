-- Job Requests & Notification Attempts Schema Migration (Compatible with VARCHAR(128) user_id & worker_id)

-- Enable PostGIS extension if not present
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Create job_requests table
CREATE TABLE IF NOT EXISTS job_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id),
  service_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | notifying | accepted | rejected_all | cancelled | expired
  job_location GEOGRAPHY(Point, 4326) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_worker_id TEXT REFERENCES workers(id),
  accepted_at TIMESTAMPTZ
);

-- 2. Create job_notification_attempts table
CREATE TABLE IF NOT EXISTS job_notification_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_request_id UUID NOT NULL REFERENCES job_requests(id) ON DELETE CASCADE,
  worker_id TEXT NOT NULL REFERENCES workers(id),
  attempt_order INT NOT NULL, -- 1st nearest, 2nd nearest...
  status TEXT NOT NULL DEFAULT 'sent', -- sent | accepted | rejected | timed_out
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  UNIQUE(job_request_id, worker_id)
);

CREATE INDEX IF NOT EXISTS idx_job_notif_job ON job_notification_attempts(job_request_id);

-- 3. Ensure workers table has fcm_token & is_available
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workers' AND column_name='fcm_token') THEN
    ALTER TABLE workers ADD COLUMN fcm_token TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='workers' AND column_name='is_available') THEN
    ALTER TABLE workers ADD COLUMN is_available BOOLEAN DEFAULT true;
  END IF;
END $$;

-- 4. Ensure users table has fcm_token
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='fcm_token') THEN
    ALTER TABLE users ADD COLUMN fcm_token TEXT;
  END IF;
END $$;
