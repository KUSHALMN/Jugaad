-- ============================================================================
-- Jugaad App — Worker Approval Missing Columns Fix
-- Adds columns that the admin approval workflow (admin.py) depends on
-- but were never applied to the production Supabase DB.
-- ============================================================================

-- 1. Add missing approval workflow columns
ALTER TABLE workers ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ NULL;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS approved_by VARCHAR(128) NULL;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS rejection_reason TEXT NULL;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS work_category VARCHAR(100) NULL;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS city VARCHAR(100) DEFAULT 'Mysuru';
ALTER TABLE workers ADD COLUMN IF NOT EXISTS total_completed_jobs INTEGER DEFAULT 0;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS approval_status_updated_at TIMESTAMPTZ NULL;

-- 2. Backfill work_category from skills[1] where null
UPDATE workers
SET work_category = skills[1]
WHERE work_category IS NULL AND skills IS NOT NULL AND array_length(skills, 1) > 0;

-- 3. Backfill total_completed_jobs from totalJobsCompleted where null
UPDATE workers
SET total_completed_jobs = COALESCE("totalJobsCompleted", total_jobs, 0)
WHERE total_completed_jobs IS NULL OR total_completed_jobs = 0;

-- 4. Backfill is_active = true for all approved workers
UPDATE workers SET is_active = TRUE WHERE status = 'approved' OR approval_status = 'approved';
UPDATE workers SET is_active = FALSE WHERE status = 'rejected' OR approval_status = 'rejected';

-- 5. Update approve_worker RPC to also set the new columns
CREATE OR REPLACE FUNCTION approve_worker(p_worker_id VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  UPDATE workers
  SET 
    status = 'approved',
    approval_status = 'approved',
    availability_status = 'online',
    is_active = TRUE,
    is_available = TRUE,
    is_online = TRUE,
    "isOnline" = TRUE,
    "isVerified" = TRUE,
    id_verified = TRUE,
    approved_at = NOW(),
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id = p_worker_id;
  
  RETURN FOUND;
END;
$$;

-- 6. Update reject_worker RPC to also set the new columns
CREATE OR REPLACE FUNCTION reject_worker(p_worker_id VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  p_reason TEXT DEFAULT 'Application criteria not met.';
BEGIN
  UPDATE workers
  SET 
    status = 'rejected',
    approval_status = 'rejected',
    availability_status = 'offline',
    is_active = FALSE,
    is_available = FALSE,
    is_online = FALSE,
    "isOnline" = FALSE,
    "isVerified" = FALSE,
    id_verified = FALSE,
    rejection_reason = p_reason,
    updated_at = NOW()
  WHERE id = p_worker_id;
  
  RETURN FOUND;
END;
$$;

-- 7. Create index for fast admin + search queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_workers_status_category ON workers(status, is_available, is_online);
CREATE INDEX IF NOT EXISTS idx_workers_is_active ON workers(is_active);
