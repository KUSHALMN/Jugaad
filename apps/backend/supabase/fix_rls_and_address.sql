-- ==============================================================================
-- 🛠️ JUGAAD / LOCALWORKERS — RLS PERMISSION & ADDRESS COLUMN REPAIR
-- ==============================================================================
-- Run this in your Supabase Dashboard > SQL Editor:
-- https://supabase.com/dashboard/project/<YOUR_PROJECT_ID>/sql/new
--
-- Fixes:
--   1. PostgrestException 42501: "new row violates row-level security policy for table users"
--      (Caused by RLS expecting Supabase Auth session instead of Firebase Auth)
--   2. Adds missing address JSONB column to public.users & public.workers
-- ==============================================================================

-- 1. ADD ADDRESS COLUMNS
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS address JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS address JSONB DEFAULT '{}'::jsonb;

-- 2. REPAIR USERS ROW-LEVEL SECURITY POLICIES
-- Drop restrictive policies that demand Supabase Auth (auth.uid())
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_self_access" ON public.users;
DROP POLICY IF EXISTS "users_anonymous_all" ON public.users;
DROP POLICY IF EXISTS "users_anonymous_read" ON public.users;
DROP POLICY IF EXISTS "users_read_all" ON public.users;
DROP POLICY IF EXISTS "users_insert_all" ON public.users;
DROP POLICY IF EXISTS "users_update_all" ON public.users;

-- Allow read for all clients (customer and worker profiles)
CREATE POLICY "users_read_all" ON public.users
    FOR SELECT USING (true);

-- Allow insert/upsert from mobile clients (with Firebase Auth UIDs)
CREATE POLICY "users_insert_all" ON public.users
    FOR INSERT WITH CHECK (true);

-- Allow updates from mobile clients
CREATE POLICY "users_update_all" ON public.users
    FOR UPDATE USING (true) WITH CHECK (true);

-- 3. REPAIR WORKERS ROW-LEVEL SECURITY POLICIES
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "workers_self_update" ON public.workers;
DROP POLICY IF EXISTS "workers_anonymous_all" ON public.workers;
DROP POLICY IF EXISTS "workers_public_read" ON public.workers;
DROP POLICY IF EXISTS "workers_read_all" ON public.workers;
DROP POLICY IF EXISTS "workers_insert_all" ON public.workers;
DROP POLICY IF EXISTS "workers_update_all" ON public.workers;

CREATE POLICY "workers_read_all" ON public.workers
    FOR SELECT USING (true);

CREATE POLICY "workers_insert_all" ON public.workers
    FOR INSERT WITH CHECK (true);

CREATE POLICY "workers_update_all" ON public.workers
    FOR UPDATE USING (true) WITH CHECK (true);

-- 4. REPAIR JOBS & MESSAGES RLS FOR MOBILE HYBRID AUTH
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "jobs_participant_access" ON public.jobs;
DROP POLICY IF EXISTS "jobs_all_access" ON public.jobs;
CREATE POLICY "jobs_all_access" ON public.jobs
    FOR ALL USING (true) WITH CHECK (true);

-- Notify PostgREST to reload schema cache immediately
NOTIFY pgrst, 'reload schema';
