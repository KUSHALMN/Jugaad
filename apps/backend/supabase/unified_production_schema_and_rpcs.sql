-- ==============================================================================
-- 🛠️ JUGAAD / LOCALWORKERS — UNIFIED PRODUCTION SCHEMA & RPC CONSOLIDATION
-- ==============================================================================
-- Execute this entire script in your Supabase Dashboard > SQL Editor:
-- https://supabase.com/dashboard/project/<YOUR_PROJECT_ID>/sql/new
--
-- This script is completely IDEMPOTENT (safe to execute multiple times).
-- It ensures:
--   1. PostGIS extension & spatial indexing are active
--   2. All missing columns on 'jobs', 'workers', 'users', 'platform_config' exist
--   3. Missing tables ('payouts', 'price_change_requests', 'services') are created
--   4. All backend RPC functions ('get_nearby_workers', 'accept_job_atomic',
--      'approve_worker', 'reject_worker', 'submit_review_atomic',
--      'update_worker_location', 'get_job_coordinates') are created/fixed
--   5. Automatic 4-digit PIN/OTP generator trigger on job creation is active
--   6. Supabase Realtime replication is enabled for instant WebSockets
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. USERS TABLE ENHANCEMENTS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY,
    firebase_uid TEXT UNIQUE,
    email TEXT,
    name TEXT DEFAULT 'User',
    phone TEXT,
    role VARCHAR(32) DEFAULT 'employer',
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS firebase_uid TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role VARCHAR(32) DEFAULT 'employer';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON public.users(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. WORKERS TABLE ENHANCEMENTS & FINTECH COLUMNS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.workers (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    name TEXT NOT NULL,
    phone TEXT,
    category TEXT,
    work_category TEXT,
    skills TEXT[] DEFAULT '{}',
    location GEOGRAPHY(POINT, 4326),
    rating NUMERIC(3,2) DEFAULT 5.0,
    hourly_rate NUMERIC DEFAULT 150.0,
    rate_per_hour NUMERIC DEFAULT 150.0,
    total_jobs INTEGER DEFAULT 0,
    total_completed_jobs INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    is_online BOOLEAN DEFAULT true,
    emergency_available BOOLEAN DEFAULT false,
    approval_status VARCHAR(32) DEFAULT 'approved',
    status VARCHAR(32) DEFAULT 'approved',
    id_verified BOOLEAN DEFAULT true,
    profile_photo TEXT,
    id_document_url TEXT,
    city VARCHAR(100) DEFAULT 'Mysuru',
    area VARCHAR(100) DEFAULT 'Mysuru',
    fcm_token TEXT,
    upi_id TEXT,
    bank_account JSONB DEFAULT '{}'::jsonb,
    payout_settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure all columns exist for existing deployments
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS work_category TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS skills TEXT[] DEFAULT '{}';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 5.0;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC DEFAULT 150.0;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS rate_per_hour NUMERIC DEFAULT 150.0;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS total_jobs INTEGER DEFAULT 0;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS total_completed_jobs INTEGER DEFAULT 0;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS emergency_available BOOLEAN DEFAULT false;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS approval_status VARCHAR(32) DEFAULT 'approved';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'approved';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS id_verified BOOLEAN DEFAULT true;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS profile_photo TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS id_document_url TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS city VARCHAR(100) DEFAULT 'Mysuru';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS area VARCHAR(100) DEFAULT 'Mysuru';
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS bank_account JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS payout_settings JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS approved_by VARCHAR(128);
ALTER TABLE public.workers ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Spatial & performance indexes on workers
CREATE INDEX IF NOT EXISTS idx_workers_location ON public.workers USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_workers_avail_online ON public.workers (is_available, is_online);
CREATE INDEX IF NOT EXISTS idx_workers_category ON public.workers(category);
CREATE INDEX IF NOT EXISTS idx_workers_rating ON public.workers(rating DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. JOBS TABLE ENHANCEMENTS (ZERO-TRUST PIN, ESCROW & AUDITING)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employer_id TEXT NOT NULL,
    worker_id TEXT,
    status VARCHAR(32) DEFAULT 'open',
    skill_required TEXT,
    title TEXT,
    description TEXT,
    location GEOGRAPHY(POINT, 4326),
    address TEXT DEFAULT '',
    amount NUMERIC(10,2) DEFAULT 150.0,
    agreed_price NUMERIC(10,2),
    payment_status VARCHAR(32) DEFAULT 'pending',
    start_pin VARCHAR(6),
    completion_pin VARCHAR(6),
    start_otp VARCHAR(6),
    completion_otp VARCHAR(6),
    start_otp_verified_at TIMESTAMPTZ,
    completion_otp_verified_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    before_work_photo TEXT,
    after_work_photo TEXT,
    completion_photo TEXT,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    job_type VARCHAR(20) DEFAULT 'normal',
    service_fee_type VARCHAR(20) DEFAULT 'normal',
    surcharge_amount DECIMAL(10,2) DEFAULT 0.00,
    scheduled_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure all PIN and lifecycle columns exist on existing table
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS start_pin VARCHAR(6);
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS completion_pin VARCHAR(6);
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS start_otp VARCHAR(6);
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS completion_otp VARCHAR(6);
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS start_otp_verified_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS completion_otp_verified_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS agreed_price NUMERIC(10,2);
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS payment_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS before_work_photo TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS after_work_photo TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS completion_photo TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS job_type VARCHAR(20) DEFAULT 'normal';
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS service_fee_type VARCHAR(20) DEFAULT 'normal';
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS surcharge_amount DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;

-- Fast query indexes on jobs
CREATE INDEX IF NOT EXISTS idx_jobs_status_created ON public.jobs(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_worker_status ON public.jobs(worker_id, status);
CREATE INDEX IF NOT EXISTS idx_jobs_employer_status ON public.jobs(employer_id, status);
CREATE INDEX IF NOT EXISTS idx_jobs_razorpay_order ON public.jobs(razorpay_order_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. PAYMENTS & ESCROW TRANSACTIONS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES public.jobs(id) ON DELETE SET NULL,
    employer_id TEXT,
    worker_id TEXT,
    amount NUMERIC(10,2) NOT NULL,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'escrowed', -- 'escrowed' | 'released' | 'refunded'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_job_id ON public.payments(job_id);
CREATE INDEX IF NOT EXISTS idx_payments_razorpay_payment_id ON public.payments(razorpay_payment_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. WORKER PAYOUTS & UPI WALLET TRANSACTIONS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    payout_mode VARCHAR(32) NOT NULL DEFAULT 'upi', -- 'upi' | 'bank_transfer'
    payout_address TEXT NOT NULL, -- UPI ID (worker@okhdfcbank) or Account Number
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- 'pending' | 'completed' | 'failed'
    reference_id TEXT, -- Bank UTR / RazorpayX Payout ID
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payouts_worker_id ON public.payouts(worker_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. REVIEWS & WORKER RATING TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID UNIQUE,
    reviewer_id TEXT NOT NULL,
    reviewee_id TEXT NOT NULL,
    rating NUMERIC(3,2) NOT NULL CHECK (rating >= 1.0 AND rating <= 5.0),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON public.reviews(reviewee_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. PRICE CHANGE REQUESTS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.price_change_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    worker_id TEXT NOT NULL,
    current_amount NUMERIC(10,2) NOT NULL,
    proposed_amount NUMERIC(10,2) NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- 'pending' | 'accepted' | 'declined'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_price_change_job_status ON public.price_change_requests(job_id, status);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. PLATFORM CONFIG TABLE (ADMIN SETTINGS)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.platform_config (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    surge_fee DECIMAL(10,2) DEFAULT 50.00,
    surge_multiplier DECIMAL(4,2) DEFAULT 1.00,
    dispatch_radius_km DECIMAL(5,1) DEFAULT 5.0,
    expanded_radius_km DECIMAL(5,1) DEFAULT 10.0,
    sms_mode VARCHAR(20) DEFAULT 'sandbox',
    websockets_sync BOOLEAN DEFAULT true,
    system_load VARCHAR(20) DEFAULT 'optimal',
    maintenance_mode BOOLEAN DEFAULT false,
    min_base_fare DECIMAL(10,2) DEFAULT 150.00,
    cancellation_fee DECIMAL(10,2) DEFAULT 50.00,
    auto_assign BOOLEAN DEFAULT true,
    otp_bypass BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by VARCHAR(128)
);

ALTER TABLE public.platform_config ADD COLUMN IF NOT EXISTS surge_multiplier DECIMAL(4,2) DEFAULT 1.00;
ALTER TABLE public.platform_config ADD COLUMN IF NOT EXISTS maintenance_mode BOOLEAN DEFAULT false;
ALTER TABLE public.platform_config ADD COLUMN IF NOT EXISTS min_base_fare DECIMAL(10,2) DEFAULT 150.00;
ALTER TABLE public.platform_config ADD COLUMN IF NOT EXISTS cancellation_fee DECIMAL(10,2) DEFAULT 50.00;
ALTER TABLE public.platform_config ADD COLUMN IF NOT EXISTS auto_assign BOOLEAN DEFAULT true;
ALTER TABLE public.platform_config ADD COLUMN IF NOT EXISTS otp_bypass BOOLEAN DEFAULT false;

INSERT INTO public.platform_config (id) VALUES (1) ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. SERVICES CATALOG TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.services (
    id VARCHAR(50) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    icon VARCHAR(100) DEFAULT '',
    image_url TEXT DEFAULT '',
    price_min DECIMAL(10,2) DEFAULT 150,
    price_max DECIMAL(10,2) DEFAULT 350,
    rating DECIMAL(3,2) DEFAULT 4.8,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.services (id, title, category, icon, image_url, price_min, price_max, rating, sort_order)
VALUES
  ('electrician', 'Electrician', 'Home', 'electrical_services_rounded', 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400', 150.00, 350.00, 4.8, 1),
  ('plumber', 'Plumber', 'Home', 'plumbing_rounded', 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400', 150.00, 350.00, 4.7, 2),
  ('laptop_repair', 'Laptop repair', 'Tech', 'laptop_mac_rounded', 'https://images.unsplash.com/photo-1588702547954-4800f964702a?w=400', 200.00, 500.00, 4.9, 3),
  ('phone_repair', 'Phone repair', 'Tech', 'phone_android_rounded', 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400', 150.00, 400.00, 4.8, 4),
  ('carpenter', 'Carpenter', 'Home', 'carpenter_rounded', 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400', 180.00, 400.00, 4.6, 5),
  ('ac_service', 'AC service', 'Home', 'ac_unit_rounded', 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400', 200.00, 500.00, 4.7, 6),
  ('stove_repair', 'Stove repair', 'Home', 'local_fire_department_rounded', 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=400', 150.00, 350.00, 4.8, 7)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  category = EXCLUDED.category,
  price_min = EXCLUDED.price_min,
  price_max = EXCLUDED.price_max,
  rating = EXCLUDED.rating;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. AUTOMATIC 4-DIGIT PIN & OTP GENERATOR TRIGGER
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_generate_job_otps()
RETURNS TRIGGER AS $$
BEGIN
    -- Synchronously populate both PIN and OTP columns with a 4-digit numeric code
    IF NEW.start_pin IS NULL AND NEW.start_otp IS NULL THEN
        NEW.start_pin := lpad(floor(random() * 9000 + 1000)::text, 4, '0');
        NEW.start_otp := NEW.start_pin;
    ELSIF NEW.start_pin IS NULL THEN
        NEW.start_pin := NEW.start_otp;
    ELSIF NEW.start_otp IS NULL THEN
        NEW.start_otp := NEW.start_pin;
    END IF;

    IF NEW.completion_pin IS NULL AND NEW.completion_otp IS NULL THEN
        NEW.completion_pin := lpad(floor(random() * 9000 + 1000)::text, 4, '0');
        NEW.completion_otp := NEW.completion_pin;
    ELSIF NEW.completion_pin IS NULL THEN
        NEW.completion_pin := NEW.completion_otp;
    ELSIF NEW.completion_otp IS NULL THEN
        NEW.completion_otp := NEW.completion_pin;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_job_otps ON public.jobs;
CREATE TRIGGER trg_generate_job_otps
BEFORE INSERT ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.fn_generate_job_otps();

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. RPC: get_nearby_workers (ROBUST HYPERLOCAL DISPATCH)
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_nearby_workers(FLOAT, FLOAT, FLOAT, TEXT, TEXT[], BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS public.get_nearby_workers(FLOAT, FLOAT, FLOAT, TEXT, TEXT[]) CASCADE;

CREATE OR REPLACE FUNCTION public.get_nearby_workers(
    user_lat FLOAT,
    user_lng FLOAT,
    radius_meters FLOAT,
    service_type TEXT,
    exclude_worker_ids TEXT[] DEFAULT ARRAY['none'],
    p_is_emergency BOOLEAN DEFAULT false
)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    phone TEXT,
    rating FLOAT,
    service_types TEXT[],
    fcm_token TEXT,
    distance_meters FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id::TEXT,
        w.name::TEXT,
        w.phone::TEXT,
        COALESCE(w.rating, 5.0)::FLOAT,
        COALESCE(w.skills, ARRAY[w.category])::TEXT[],
        COALESCE(w.fcm_token, u.fcm_token, '')::TEXT as fcm_token,
        ST_Distance(
            w.location,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
        )::FLOAT as distance_meters
    FROM public.workers w
    LEFT JOIN public.users u ON (u.id = w.id OR u.firebase_uid = w.id)
    WHERE 
        COALESCE(w.is_online, true) = true
        AND COALESCE(w.is_available, true) = true
        AND (
            service_type IS NULL 
            OR service_type = '' 
            OR w.category = service_type
            OR w.skills @> ARRAY[service_type]
        )
        AND w.id::TEXT != ALL(exclude_worker_ids)
        AND (NOT p_is_emergency OR w.emergency_available = true)
        AND (
            w.location IS NULL 
            OR ST_DWithin(
                w.location,
                ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
                radius_meters
            )
        )
    ORDER BY distance_meters ASC NULLS LAST
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. RPC: accept_job_atomic (RACE CONDITION GUARD)
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.accept_job_atomic(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.accept_job_atomic(UUID, VARCHAR) CASCADE;

CREATE OR REPLACE FUNCTION public.accept_job_atomic(
    p_job_id UUID,
    p_worker_id TEXT
)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    v_updated_rows INT;
BEGIN
    -- Atomically assign worker and update status to accepted
    UPDATE public.jobs
    SET 
        worker_id = p_worker_id,
        status = 'accepted',
        accepted_at = NOW(),
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_job_id AND status IN ('open', 'searching', 'matched');

    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

    IF v_updated_rows = 0 THEN
        RETURN FALSE;
    END IF;

    -- Mark worker as busy/unavailable
    UPDATE public.workers
    SET 
        is_available = false,
        updated_at = NOW()
    WHERE id::TEXT = p_worker_id::TEXT;

    RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. RPC: approve_worker & reject_worker (KYC VERIFICATION)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.approve_worker(p_worker_id TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.workers
    SET 
        status = 'approved',
        approval_status = 'approved',
        is_available = true,
        is_online = true,
        id_verified = true,
        is_active = true,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id::TEXT = p_worker_id::TEXT;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_worker(p_worker_id TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.workers
    SET 
        status = 'rejected',
        approval_status = 'rejected',
        is_available = false,
        is_online = false,
        is_active = false,
        updated_at = NOW()
    WHERE id::TEXT = p_worker_id::TEXT;

    RETURN FOUND;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. RPC: update_worker_location (GPS TELEMETRY)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_worker_location(
    p_worker_id TEXT,
    p_lat FLOAT,
    p_lng FLOAT,
    p_available BOOLEAN DEFAULT true
)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.workers
    SET 
        location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        is_available = p_available,
        is_online = true,
        updated_at = NOW()
    WHERE id::TEXT = p_worker_id::TEXT;

    RETURN FOUND;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. RPC: submit_review_atomic & increment_worker_total_jobs
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_review_atomic(
    p_job_id UUID,
    p_reviewer_id TEXT,
    p_reviewee_id TEXT,
    p_rating INT,
    p_comment TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_new_rating DECIMAL;
BEGIN
    INSERT INTO public.reviews(job_id, reviewer_id, reviewee_id, rating, comment)
    VALUES (p_job_id, p_reviewer_id, p_reviewee_id, p_rating, p_comment)
    ON CONFLICT (job_id) DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment;

    SELECT COALESCE(AVG(rating), 5.0) INTO v_new_rating
    FROM public.reviews 
    WHERE reviewee_id::TEXT = p_reviewee_id::TEXT;

    UPDATE public.workers 
    SET rating = ROUND(v_new_rating, 2)
    WHERE id::TEXT = p_reviewee_id::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_worker_total_jobs(p_worker_id TEXT)
RETURNS VOID LANGUAGE sql AS $$
    UPDATE public.workers 
    SET 
        total_jobs = COALESCE(total_jobs, 0) + 1,
        total_completed_jobs = COALESCE(total_completed_jobs, 0) + 1,
        updated_at = NOW()
    WHERE id::TEXT = p_worker_id::TEXT;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. RPC: get_job_coordinates
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_job_coordinates(p_job_id UUID)
RETURNS TABLE (lat FLOAT, lng FLOAT) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ST_Y(location::geometry)::FLOAT as lat,
        ST_X(location::geometry)::FLOAT as lng
    FROM public.jobs
    WHERE id = p_job_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. ENABLE SUPABASE REALTIME REPLICATION
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs;
    EXCEPTION WHEN duplicate_object THEN END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.workers;
    EXCEPTION WHEN duplicate_object THEN END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.payouts;
    EXCEPTION WHEN duplicate_object THEN END;
END $$;

NOTIFY pgrst, 'reload schema';
