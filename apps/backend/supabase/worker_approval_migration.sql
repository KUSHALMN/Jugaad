-- Worker Approval Workflow Database Migration

-- 1. Ensure worker status columns exist on workers table
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workers' AND column_name = 'status') THEN
    ALTER TABLE workers ADD COLUMN status VARCHAR(30) DEFAULT 'pending_approval';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workers' AND column_name = 'approval_status') THEN
    ALTER TABLE workers ADD COLUMN approval_status VARCHAR(30) DEFAULT 'pending_approval';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workers' AND column_name = 'rejection_reason') THEN
    ALTER TABLE workers ADD COLUMN rejection_reason TEXT NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workers' AND column_name = 'approved_at') THEN
    ALTER TABLE workers ADD COLUMN approved_at TIMESTAMPTZ NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'workers' AND column_name = 'approved_by') THEN
    ALTER TABLE workers ADD COLUMN approved_by VARCHAR(128) NULL;
  END IF;
END $$;

-- 2. Backfill status column for existing records if null
UPDATE workers SET status = 'approved', approval_status = 'approved' WHERE approval_status = 'approved' OR status IS NULL OR status = 'approved';
UPDATE workers SET status = 'pending_approval' WHERE status IS NULL OR status = 'pending';

-- 3. Create index for fast admin status filtering and user search queries
CREATE INDEX IF NOT EXISTS idx_workers_status_category ON workers(status, is_available, is_online);
