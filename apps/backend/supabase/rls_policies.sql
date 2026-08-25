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

-- Workers: public permissive read/write
CREATE POLICY "workers_anonymous_all" ON workers
  FOR ALL USING (true) WITH CHECK (true);

-- Jobs: public permissive read/write
CREATE POLICY "jobs_anonymous_all" ON jobs
  FOR ALL USING (true) WITH CHECK (true);

-- Bookings: public permissive read/write
CREATE POLICY "bookings_anonymous_all" ON bookings
  FOR ALL USING (true) WITH CHECK (true);

-- Payout requests: public permissive read/write
CREATE POLICY "payout_requests_anonymous_all" ON payout_requests
  FOR ALL USING (true) WITH CHECK (true);

-- Reviews: public permissive read/write
CREATE POLICY "reviews_anonymous_all" ON reviews
  FOR ALL USING (true) WITH CHECK (true);

-- Payments: public permissive read/write
CREATE POLICY "payments_anonymous_all" ON payments
  FOR ALL USING (true) WITH CHECK (true);

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
