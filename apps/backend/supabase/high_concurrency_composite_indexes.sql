-- ============================================================================
-- Jugaad App — High-Concurrency Composite Indexes Migration
-- ============================================================================
-- Optimizes high-throughput polling and analytical queries across core tables:
--   - jobs: employer polling, worker polling, dispatch queries, payment reconciliation
--   - users: Firebase UID lookups, phone lookups
--   - workers: category + availability filtering, rating computations
--   - reviews: worker rating aggregations
--   - price_change_requests & spare_parts: active job item lookups
-- ============================================================================

-- 1. Jobs Table Composite Indexes
CREATE INDEX IF NOT EXISTS idx_jobs_employer_status 
  ON public.jobs (employer_id, status);

CREATE INDEX IF NOT EXISTS idx_jobs_worker_status 
  ON public.jobs (worker_id, status);

CREATE INDEX IF NOT EXISTS idx_jobs_status_created_at_desc 
  ON public.jobs (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_jobs_payment_status 
  ON public.jobs (payment_status, status);

CREATE INDEX IF NOT EXISTS idx_jobs_razorpay_order_id 
  ON public.jobs (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

-- 2. Users Table High-Concurrency Auth Lookups
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid 
  ON public.users (firebase_uid);

CREATE INDEX IF NOT EXISTS idx_users_phone 
  ON public.users (phone);

-- 3. Workers Table Status & Category Filtering
CREATE INDEX IF NOT EXISTS idx_workers_category_online_avail 
  ON public.workers (category, is_online, is_available);

CREATE INDEX IF NOT EXISTS idx_workers_phone 
  ON public.workers (phone);

-- 4. Reviews & Reputation Aggregation
CREATE INDEX IF NOT EXISTS idx_reviews_worker_id_rating 
  ON public.reviews (worker_id, rating);

-- 5. Active Job Sub-Entities (Negotiations & Add-ons)
CREATE INDEX IF NOT EXISTS idx_price_change_requests_job_status 
  ON public.price_change_requests (job_id, status);

CREATE INDEX IF NOT EXISTS idx_spare_parts_job_status 
  ON public.spare_parts (job_id, status);
