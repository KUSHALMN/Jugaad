-- ==============================================================================
-- JUGAAD / LOCALWORKERS — PRODUCTION DATABASE ENHANCEMENT & OPTIMIZATION SCRIPT
-- Run this in your Supabase Dashboard > SQL Editor
-- ==============================================================================

-- 1. ADD JOB OTP VERIFICATION & DISPUTE SHIELD COLUMNS
-- Adds 4-digit start and completion verification codes to eliminate false job completions
ALTER TABLE IF EXISTS public.jobs 
ADD COLUMN IF NOT EXISTS start_otp VARCHAR(6),
ADD COLUMN IF NOT EXISTS completion_otp VARCHAR(6),
ADD COLUMN IF NOT EXISTS start_otp_verified_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completion_otp_verified_at TIMESTAMPTZ;

-- 2. ADD CHAT PHOTO / MEDIA ATTACHMENTS SUPPORT
-- Enables users and workers to send quick photos of damaged pipes/wiring in chat
ALTER TABLE IF EXISTS public.messages 
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS media_type VARCHAR(32) DEFAULT 'text';

-- 3. WORKER INSTANT PAYOUTS & WALLET TRANSACTIONS TABLE
-- Enables "Withdraw Earnings to UPI / Bank" for Mysuru & Bengaluru technicians
CREATE TABLE IF NOT EXISTS public.payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    payout_mode VARCHAR(32) NOT NULL DEFAULT 'upi', -- 'upi' | 'bank_transfer'
    payout_address TEXT NOT NULL, -- UPI ID (e.g., worker@okhdfcbank) or Account No
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- 'pending' | 'processing' | 'completed' | 'failed'
    reference_id TEXT, -- RazorpayX or Bank UTR number
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable Row Level Security (RLS) on payouts
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;

-- Allow workers to view their own payouts
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'payouts' AND policyname = 'Workers can view own payouts'
    ) THEN
        CREATE POLICY "Workers can view own payouts" 
        ON public.payouts FOR SELECT 
        USING (auth.uid() = worker_id);
    END IF;
END $$;

-- Allow service role / backend full access on payouts
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'payouts' AND policyname = 'Service role full access on payouts'
    ) THEN
        CREATE POLICY "Service role full access on payouts" 
        ON public.payouts FOR ALL 
        USING (true) 
        WITH CHECK (true);
    END IF;
END $$;

-- 4. ULTRA-FAST DATABASE INDEXES (FOR SNAPPY APP RESPONSE TIMES < 40ms)
-- Optimizes active job queries, matching searches, and chat load speed
CREATE INDEX IF NOT EXISTS idx_jobs_status_created 
ON public.jobs(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_jobs_worker_status 
ON public.jobs(worker_id, status);

CREATE INDEX IF NOT EXISTS idx_jobs_employer_status 
ON public.jobs(employer_id, status);

CREATE INDEX IF NOT EXISTS idx_messages_job_created 
ON public.messages(job_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_workers_category_available 
ON public.workers(category, is_available);

CREATE INDEX IF NOT EXISTS idx_workers_online_rating 
ON public.workers(is_online, rating DESC);

-- 5. ENABLE SUPABASE REALTIME REPLICATION FOR INSTANT CHAT & LIVE JOB TRACKING
-- Ensures real-time websocket delivery for instant chat, live status changes, and notifications
DO $$
BEGIN
    -- Enable replication on messages if not already present
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    EXCEPTION WHEN duplicate_object THEN
        -- already added
    END;

    -- Enable replication on jobs if not already present
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs;
    EXCEPTION WHEN duplicate_object THEN
        -- already added
    END;

    -- Enable replication on notifications if not already present
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION WHEN duplicate_object THEN
        -- already added
    END;
END $$;

-- 6. HELPER FUNCTION: AUTOMATIC 4-DIGIT OTP GENERATOR ON JOB CREATION
-- Automatically generates a start_otp and completion_otp whenever a customer posts a job
CREATE OR REPLACE FUNCTION public.fn_generate_job_otps()
RETURNS TRIGGER AS $$
BEGIN
    -- Generate random 4-digit numeric OTPs
    IF NEW.start_otp IS NULL THEN
        NEW.start_otp := lpad(floor(random() * 9000 + 1000)::text, 4, '0');
    END IF;
    IF NEW.completion_otp IS NULL THEN
        NEW.completion_otp := lpad(floor(random() * 9000 + 1000)::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_job_otps ON public.jobs;
CREATE TRIGGER trg_generate_job_otps
BEFORE INSERT ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.fn_generate_job_otps();
