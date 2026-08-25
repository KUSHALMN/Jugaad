-- ============================================
-- JUGAAD MVP — Migration: Seed Verified Workers Table & Column Additions
-- ============================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create verified_seed_workers table
CREATE TABLE IF NOT EXISTS verified_seed_workers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  location GEOGRAPHY(POINT, 4326),
  google_place_id TEXT UNIQUE,
  google_maps_url TEXT,
  rating NUMERIC(3,2) DEFAULT 0.0,
  review_count INT DEFAULT 0,
  is_seed_verified BOOLEAN DEFAULT true,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for location on verified_seed_workers
CREATE INDEX IF NOT EXISTS idx_verified_seed_workers_location 
ON verified_seed_workers USING GIST (location);

-- Index for google_place_id on verified_seed_workers
CREATE INDEX IF NOT EXISTS idx_verified_seed_workers_place_id 
ON verified_seed_workers (google_place_id);

-- 2. Add seed worker columns to existing workers table
ALTER TABLE workers ADD COLUMN IF NOT EXISTS google_place_id TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS google_maps_url TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS is_seed_verified BOOLEAN DEFAULT true;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS work_category TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;

-- Ensure GIST index on workers.location
CREATE INDEX IF NOT EXISTS idx_workers_location 
ON workers USING GIST (location);

-- Permissive RLS policies for seed workers
ALTER TABLE verified_seed_workers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "verified_seed_workers_public_read" ON verified_seed_workers;
CREATE POLICY "verified_seed_workers_public_read" ON verified_seed_workers
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "verified_seed_workers_service_all" ON verified_seed_workers;
CREATE POLICY "verified_seed_workers_service_all" ON verified_seed_workers
  FOR ALL USING (true) WITH CHECK (true);
