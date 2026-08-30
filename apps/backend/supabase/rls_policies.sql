-- ============================================
-- JUGAAD MVP — Supabase Row Level Security (RLS)
-- Replaces firestore.rules
-- Run this in Supabase SQL Editor AFTER schema.sql
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE outbox_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE geocache ENABLE ROW LEVEL SECURITY;

-- Users: users can only read and write their own profile
DROP POLICY IF EXISTS "users_anonymous_all" ON users;
CREATE POLICY "users_self_access" ON users
  FOR ALL USING (auth.uid()::text = id::text) WITH CHECK (auth.uid()::text = id::text);

-- Allow public read of profiles so customer and worker details can load
DROP POLICY IF EXISTS "users_anonymous_read" ON users;
CREATE POLICY "users_anonymous_read" ON users
  FOR SELECT USING (true);

-- Workers: Approved profiles are readable; updates allowed only for self or admin
DROP POLICY IF EXISTS "workers_anonymous_all" ON workers;
DROP POLICY IF EXISTS "workers_public_read" ON workers;
DROP POLICY IF EXISTS "workers_self_update" ON workers;

CREATE POLICY "workers_public_read" ON workers
  FOR SELECT USING (approval_status = 'approved' OR status = 'approved' OR auth.uid()::text = id::text);

CREATE POLICY "workers_self_update" ON workers
  FOR UPDATE USING (
    auth.uid()::text = id::text 
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  )
  WITH CHECK (
    auth.uid()::text = id::text 
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  );

-- Jobs: Only employer, assigned worker, or admins can read/update
DROP POLICY IF EXISTS "jobs_anonymous_all" ON jobs;
DROP POLICY IF EXISTS "jobs_participant_access" ON jobs;

CREATE POLICY "jobs_participant_access" ON jobs
  FOR ALL USING (
    auth.uid()::text = employer_id::text 
    OR auth.uid()::text = worker_id::text
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  )
  WITH CHECK (
    auth.uid()::text = employer_id::text 
    OR auth.uid()::text = worker_id::text
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  );

-- Bookings: Only employer, assigned worker, or admin
DROP POLICY IF EXISTS "bookings_anonymous_all" ON bookings;
DROP POLICY IF EXISTS "bookings_participant_access" ON bookings;

CREATE POLICY "bookings_participant_access" ON bookings
  FOR ALL USING (
    auth.uid()::text = employer_id::text 
    OR auth.uid()::text = worker_id::text
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  );

-- Payout requests: Worker owner or admin only
DROP POLICY IF EXISTS "payout_requests_anonymous_all" ON payout_requests;
DROP POLICY IF EXISTS "payout_requests_owner_access" ON payout_requests;

CREATE POLICY "payout_requests_owner_access" ON payout_requests
  FOR ALL USING (
    auth.uid()::text = worker_id::text
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  );

-- Reviews: Public read; create only by job employer
DROP POLICY IF EXISTS "reviews_anonymous_all" ON reviews;
DROP POLICY IF EXISTS "reviews_public_read" ON reviews;
DROP POLICY IF EXISTS "reviews_author_write" ON reviews;

CREATE POLICY "reviews_public_read" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "reviews_author_write" ON reviews
  FOR INSERT WITH CHECK (auth.uid()::text = reviewer_id::text);

-- Payments: Only participants and admins can read payments
DROP POLICY IF EXISTS "payments_anonymous_all" ON payments;
DROP POLICY IF EXISTS "payments_participant_read" ON payments;

CREATE POLICY "payments_participant_read" ON payments
  FOR SELECT USING (
    auth.uid()::text = employer_id::text 
    OR auth.uid()::text = worker_id::text
    OR EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid()::text AND users.role = 'admin')
  );

-- Notifications: server-only (no direct client access)
CREATE POLICY "notifications_server_only" ON notifications
  FOR ALL USING (false);  -- Service role key bypasses RLS

-- Admin log: server-only
CREATE POLICY "admin_log_server_only" ON admin_log
  FOR ALL USING (false);

-- Outbox: server-only
CREATE POLICY "outbox_server_only" ON outbox_events
  FOR ALL USING (false);

-- Scheduled jobs: server-only
CREATE POLICY "scheduled_jobs_server_only" ON scheduled_jobs
  FOR ALL USING (false);

-- Geocache: server-only
CREATE POLICY "geocache_server_only" ON geocache
  FOR ALL USING (false);

-- Backfill existing firebase_uid values for backward compatibility with backend gateway services
UPDATE users SET firebase_uid = id WHERE firebase_uid IS NULL;
