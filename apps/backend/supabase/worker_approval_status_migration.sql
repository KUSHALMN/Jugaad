-- ============================================================================
-- Jugaad App — Worker Approval Status & RPC Functions Migration
-- ============================================================================

-- 1. Add availability_status column to workers table if not exists
ALTER TABLE workers ADD COLUMN IF NOT EXISTS availability_status VARCHAR(50) DEFAULT 'offline';

-- 2. Create or replace the approve_worker RPC function
CREATE OR REPLACE FUNCTION approve_worker(p_worker_id VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  UPDATE workers
  SET 
    status = 'approved',
    availability_status = 'online',
    approval_status = 'approved',
    is_online = true,
    "isOnline" = true,
    is_available = true,
    id_verified = true,
    "isVerified" = true,
    updated_at = NOW()
  WHERE id = p_worker_id;
  
  RETURN FOUND;
END;
$$;

-- 3. Create or replace the reject_worker RPC function
CREATE OR REPLACE FUNCTION reject_worker(p_worker_id VARCHAR)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  UPDATE workers
  SET 
    status = 'rejected',
    availability_status = 'offline',
    approval_status = 'rejected',
    is_online = false,
    "isOnline" = false,
    is_available = false,
    id_verified = false,
    "isVerified" = false,
    updated_at = NOW()
  WHERE id = p_worker_id;
  
  RETURN FOUND;
END;
$$;
