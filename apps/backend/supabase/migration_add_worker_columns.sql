-- ============================================
-- JUGAAD MVP — Migration: Ensure workers table exists with all columns
-- Run this in Supabase SQL Editor to fix document upload
-- ============================================

-- Required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 1: Create workers table WITHOUT foreign key constraint
-- (Avoids type mismatch issues with existing users table)
CREATE TABLE IF NOT EXISTS workers (
  id TEXT PRIMARY KEY,
  worker_id TEXT,
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

-- Step 2: If the table already existed, add any missing columns
DO $$ BEGIN
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS worker_id TEXT;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS name VARCHAR(100);
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS phone VARCHAR(15);
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS area VARCHAR(200);
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS specialities TEXT[] DEFAULT '{}';
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS rate_per_hour INTEGER DEFAULT 150;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS "totalJobsCompleted" INTEGER DEFAULT 0;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS "totalEarnings" VARCHAR(20) DEFAULT '0';
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS experience VARCHAR(20);
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS "isVerified" BOOLEAN DEFAULT true;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS documents JSONB DEFAULT '[]';
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS approval_status VARCHAR(30) DEFAULT 'pending';
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS status VARCHAR(30) DEFAULT 'offline';
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS "isOnline" BOOLEAN DEFAULT false;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS last_online_at TIMESTAMPTZ;
  ALTER TABLE workers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
END $$;

-- Step 3: Enable RLS and set permissive policy
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "workers_anonymous_all" ON workers;
CREATE POLICY "workers_anonymous_all" ON workers
  FOR ALL USING (true) WITH CHECK (true);
