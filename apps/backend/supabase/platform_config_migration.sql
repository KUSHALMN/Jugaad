-- ============================================
-- PLATFORM CONFIG (Admin-managed settings)
-- Single-row table for platform-wide configuration.
-- Admin dashboard writes, all clients read.
-- ============================================

CREATE TABLE IF NOT EXISTS platform_config (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  surge_fee DECIMAL(10,2) DEFAULT 50.00,
  dispatch_radius_km DECIMAL(5,1) DEFAULT 5.0,
  expanded_radius_km DECIMAL(5,1) DEFAULT 10.0,
  sms_mode VARCHAR(20) DEFAULT 'sandbox',
  websockets_sync BOOLEAN DEFAULT true,
  system_load VARCHAR(20) DEFAULT 'optimal',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by VARCHAR(128)
);

-- Seed the initial config row
INSERT INTO platform_config (id) VALUES (1) ON CONFLICT DO NOTHING;

-- RLS: allow anonymous reads (mobile apps need to fetch config)
ALTER TABLE platform_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "platform_config_read" ON platform_config
  FOR SELECT USING (true);

-- Schema reload notification for PostgREST
NOTIFY pgrst, 'reload schema';
