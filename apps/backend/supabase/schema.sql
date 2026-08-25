-- ============================================
-- JUGAAD MVP — Supabase PostgreSQL Schema
-- Replaces ALL Firestore collections
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- EXTENSIONS
-- ============================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_net;  -- For HTTP calls from Postgres triggers

-- ============================================
-- ENUMS
-- ============================================
DO $$ BEGIN
  CREATE TYPE job_status AS ENUM (
    'open', 'matched', 'accepted', 'in_progress', 
    'completed', 'cancelled', 'disputed'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'pending', 'escrowed', 'released', 'refunded', 'failed'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('worker', 'employer', 'admin');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- DROP EXISTING TABLES
-- ============================================
DROP TABLE IF EXISTS 
  geocache, admin_log, outbox_events, reviews, notifications, 
  payout_requests, payments, scheduled_jobs, bookings, jobs, 
  workers, users CASCADE;

-- ============================================
-- USERS (replaces Firestore users/{id})
-- firebase_uid is the unique key from Firebase Auth
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(128) PRIMARY KEY,  -- Stores Firebase UID directly
  firebase_uid VARCHAR(128) UNIQUE,  -- Kept for backward compatibility with backend services
  phone VARCHAR(15) UNIQUE,
  name VARCHAR(100),
  email VARCHAR(255),
  role user_role NOT NULL,
  fcm_token TEXT,
  notification_prefs JSONB DEFAULT '{}',
  saved_addresses JSONB DEFAULT '[]',
  default_address_index INTEGER DEFAULT 0,
  address JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- WORKERS (replaces Firestore workers/{id})
-- skills as TEXT[] array (was Firestore array field)
-- location as PostGIS GEOGRAPHY (replaces geohash)
-- ============================================
CREATE TABLE IF NOT EXISTS workers (
  id VARCHAR(128) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  worker_id VARCHAR(128),
  name VARCHAR(100),
  phone VARCHAR(15),
  area VARCHAR(200),
  skills TEXT[] NOT NULL DEFAULT '{}',
  specialities TEXT[] DEFAULT '{}',
  is_available BOOLEAN DEFAULT true,
  location GEOGRAPHY(POINT, 4326),
  hourly_rate DECIMAL(8,2),
  rate_per_hour INTEGER DEFAULT 150,
  rating DECIMAL(3,2) DEFAULT 0.0,
  total_jobs INTEGER DEFAULT 0,
  "totalJobsCompleted" INTEGER DEFAULT 0,
  "totalEarnings" VARCHAR(20) DEFAULT '0',
  experience VARCHAR(20),
  bio TEXT,
  id_verified BOOLEAN DEFAULT false,
  "isVerified" BOOLEAN DEFAULT true,
  id_document_url TEXT,
  documents JSONB DEFAULT '[]',
  approval_status VARCHAR(30) DEFAULT 'pending',
  status VARCHAR(30) DEFAULT 'offline',
  "isOnline" BOOLEAN DEFAULT false,
  last_online_at TIMESTAMPTZ,
  is_online BOOLEAN DEFAULT false,
  notification_prefs JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- JOBS (replaces Firestore jobs/{id})
-- ============================================
CREATE TABLE IF NOT EXISTS jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employer_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  worker_id VARCHAR(128) REFERENCES users(id),
  skill_required VARCHAR(100) NOT NULL,
  title VARCHAR(200),
  description TEXT,
  location GEOGRAPHY(POINT, 4326),
  address TEXT,
  status job_status DEFAULT 'open',
  amount DECIMAL(10,2),
  payment_status payment_status DEFAULT 'pending',
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- BOOKINGS (replaces Firestore bookings/{id})
-- ============================================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES jobs(id) NOT NULL,
  worker_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  employer_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  status VARCHAR(30) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- SCHEDULED JOBS (replaces Firestore scheduled_jobs/{id})
-- ============================================
CREATE TABLE IF NOT EXISTS scheduled_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES jobs(id) NOT NULL,
  qstash_message_id TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  executed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PAYMENTS (replaces Firestore payments/{id})
-- ============================================
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES jobs(id),
  employer_id VARCHAR(128) REFERENCES users(id),
  worker_id VARCHAR(128) REFERENCES users(id),
  amount DECIMAL(10,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'INR',
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT,
  status payment_status DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PAYOUT REQUESTS (replaces Firestore payout_requests/{id})
-- ============================================
CREATE TABLE IF NOT EXISTS payout_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id VARCHAR(128) REFERENCES workers(id) NOT NULL,
  job_id UUID REFERENCES jobs(id) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- NOTIFICATIONS (replaces Firestore notifications/{id})
-- Idempotency via UNIQUE constraint (replaces gcp_exc.AlreadyExists)
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  job_id UUID REFERENCES jobs(id),
  type VARCHAR(50) NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  sent BOOLEAN DEFAULT false,
  idempotency_key VARCHAR(255) UNIQUE,  -- ON CONFLICT DO NOTHING replaces AlreadyExists
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- REVIEWS (replaces Firestore jobs/{id}/reviews subcollection)
-- Now a flat table with job_id FK
-- ============================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES jobs(id) UNIQUE,
  reviewer_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  reviewee_id VARCHAR(128) REFERENCES users(id) NOT NULL,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5) NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- OUTBOX EVENTS (replaces Firestore jobs/{id}/outbox/{eid} subcollection)
-- Flat table with job_id FK — outbox_publisher service is DELETED
-- ============================================
CREATE TABLE IF NOT EXISTS outbox_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES jobs(id),
  event_type VARCHAR(100) NOT NULL,
  payload JSONB NOT NULL,
  published BOOLEAN DEFAULT false,
  retry_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ADMIN LOG (replaces Firestore admin_log collection)
-- ============================================
CREATE TABLE IF NOT EXISTS admin_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id VARCHAR(128) REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  target_id UUID,
  target_table VARCHAR(50),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- GEOCACHE (replaces Firestore geocache/{geohash})
-- ============================================
CREATE TABLE IF NOT EXISTS geocache (
  geohash VARCHAR(10) PRIMARY KEY,
  address TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_workers_location ON workers USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_workers_skills ON workers USING GIN(skills);
CREATE INDEX IF NOT EXISTS idx_workers_available ON workers(is_available) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_employer ON jobs(employer_id);
CREATE INDEX IF NOT EXISTS idx_jobs_worker ON jobs(worker_id);
CREATE INDEX IF NOT EXISTS idx_jobs_location ON jobs USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_outbox_unpublished ON outbox_events(published) WHERE published = false;
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_job ON bookings(job_id);

-- ============================================
-- OUTBOX TRIGGER (replaces outbox_publisher service entirely)
-- On INSERT into outbox_events → call matching/notification service via pg_net
-- ============================================
DROP FUNCTION IF EXISTS notify_outbox_event CASCADE;
CREATE OR REPLACE FUNCTION notify_outbox_event()
RETURNS TRIGGER AS $$
BEGIN
  -- Fire HTTP to ops-service dispatcher (Render internal URL)
  PERFORM net.http_post(
    url := current_setting('app.ops_service_url') || '/internal/outbox/dispatch',
    body := row_to_json(NEW)::text::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Internal-Secret', current_setting('app.internal_secret')
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER outbox_event_trigger
  AFTER INSERT ON outbox_events
  FOR EACH ROW EXECUTE FUNCTION notify_outbox_event();

-- ============================================
-- RPC FUNCTIONS (called via supabase.rpc())
-- ============================================

-- find_nearby_workers: replaces Firestore geohash queries with PostGIS ST_DWithin
DROP FUNCTION IF EXISTS find_nearby_workers CASCADE;
CREATE OR REPLACE FUNCTION find_nearby_workers(
  lat FLOAT, lng FLOAT, skill TEXT, radius_meters INT
)
RETURNS TABLE(id VARCHAR(128), name TEXT, phone TEXT, rating DECIMAL, distance_meters FLOAT)
LANGUAGE sql AS $$
  SELECT w.id, u.name, u.phone, w.rating,
    ST_Distance(w.location, ST_MakePoint(lng, lat)::GEOGRAPHY) as distance_meters
  FROM workers w
  JOIN users u ON w.id = u.id
  WHERE w.is_available = true
    AND u.is_active = true
    AND skill = ANY(w.skills)
    AND ST_DWithin(w.location, ST_MakePoint(lng, lat)::GEOGRAPHY, radius_meters)
  ORDER BY distance_meters ASC
  LIMIT 10;
$$;

-- accept_job_atomic: replaces Firestore transaction for job acceptance
DROP FUNCTION IF EXISTS accept_job_atomic CASCADE;
CREATE OR REPLACE FUNCTION accept_job_atomic(p_job_id UUID, p_worker_id VARCHAR(128))
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  v_employer_id VARCHAR(128);
BEGIN
  -- Retrieve employer_id from the job
  SELECT employer_id INTO v_employer_id FROM jobs WHERE id = p_job_id AND status IN ('open', 'matched');
  
  IF v_employer_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Update job status, assign worker, and increment version
  UPDATE jobs SET status = 'accepted', worker_id = p_worker_id, version = version + 1, updated_at = NOW()
  WHERE id = p_job_id AND status IN ('open', 'matched');

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

-- complete_booking_atomic: replaces Firestore transaction for booking completion
DROP FUNCTION IF EXISTS complete_booking_atomic CASCADE;
CREATE OR REPLACE FUNCTION complete_booking_atomic(p_booking_id UUID, p_worker_id VARCHAR(128))
RETURNS DECIMAL LANGUAGE plpgsql AS $$
DECLARE
  v_amount DECIMAL;
BEGIN
  -- Update booking
  UPDATE bookings SET status = 'completed', updated_at = NOW()
  WHERE id = p_booking_id AND worker_id = p_worker_id AND status IN ('in_progress', 'confirmed');

  -- Get the actual amount from the related job
  SELECT COALESCE(j.amount, 0) INTO v_amount
  FROM bookings b JOIN jobs j ON b.job_id = j.id
  WHERE b.id = p_booking_id;

  -- Update worker financial counters
  UPDATE workers SET
    total_jobs = total_jobs + 1,
    updated_at = NOW()
  WHERE id = p_worker_id;

  RETURN v_amount;
END;
$$;

-- submit_review_atomic: replaces Firestore transaction for review + rating update
DROP FUNCTION IF EXISTS submit_review_atomic CASCADE;
CREATE OR REPLACE FUNCTION submit_review_atomic(
  p_job_id UUID, p_reviewer_id VARCHAR(128), p_reviewee_id VARCHAR(128),
  p_rating INT, p_comment TEXT
)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_new_rating DECIMAL;
BEGIN
  -- Insert review (UNIQUE on job_id prevents duplicates)
  INSERT INTO reviews(job_id, reviewer_id, reviewee_id, rating, comment)
  VALUES (p_job_id, p_reviewer_id, p_reviewee_id, p_rating, p_comment);

  -- Calculate the actual average rating of all reviews for this worker
  SELECT COALESCE(AVG(rating), 0.0) INTO v_new_rating
  FROM reviews WHERE reviewee_id = p_reviewee_id;

  -- Update worker aggregate rating
  UPDATE workers SET rating = ROUND(v_new_rating, 2)
  WHERE id = p_reviewee_id;
END;
$$;

-- increment_worker_total_jobs: atomic helper called by booking_service
DROP FUNCTION IF EXISTS increment_worker_total_jobs CASCADE;
CREATE OR REPLACE FUNCTION increment_worker_total_jobs(p_worker_id VARCHAR(128))
RETURNS void LANGUAGE sql AS $$
  UPDATE workers SET total_jobs = total_jobs + 1, updated_at = NOW()
  WHERE id = p_worker_id;
$$;

-- ============================================
-- POST-DEPLOY: Set runtime config
-- Run these after deploying your Render services:
-- ============================================
-- ALTER DATABASE postgres SET app.ops_service_url = 'https://jugaad-ops.onrender.com';
-- ALTER DATABASE postgres SET app.internal_secret = 'your-internal-secret';

-- ============================================
-- REALTIME REPLICATION CONFIG
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE jobs, bookings;
ALTER TABLE jobs REPLICA IDENTITY FULL;
ALTER TABLE bookings REPLICA IDENTITY FULL;
