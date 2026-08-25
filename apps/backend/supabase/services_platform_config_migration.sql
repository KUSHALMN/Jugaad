-- Migration: Create services and platform_config tables
-- These tables were referenced by main.py but did not exist in Supabase.

-- ════════════════════════════════════════════════════════════════
-- 1. SERVICES TABLE
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS services (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Home',
  icon TEXT DEFAULT '',
  image_url TEXT DEFAULT '',
  price_min INTEGER DEFAULT 150,
  price_max INTEGER DEFAULT 350,
  rating DECIMAL(3,2) DEFAULT 4.5,
  sort_order INTEGER DEFAULT 100,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed services catalog
INSERT INTO services (id, title, category, icon, image_url, price_min, price_max, rating, sort_order, is_active) VALUES
  ('electrician', 'Electrician', 'Home', 'electrical_services_rounded', 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400', 150, 350, 4.8, 1, true),
  ('plumber', 'Plumber', 'Home', 'plumbing_rounded', 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400', 150, 350, 4.7, 2, true),
  ('laptop_repair', 'Laptop repair', 'Tech', 'laptop_mac_rounded', 'https://images.unsplash.com/photo-1588702547954-4800f964702a?w=400', 200, 500, 4.9, 3, true),
  ('phone_repair', 'Phone repair', 'Tech', 'phone_android_rounded', 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400', 150, 400, 4.8, 4, true),
  ('carpenter', 'Carpenter', 'Home', 'carpenter_rounded', 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400', 180, 400, 4.6, 5, true),
  ('painter', 'Painter', 'Home', 'format_paint_rounded', 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?w=400', 250, 600, 4.8, 6, true),
  ('ac_service', 'AC service', 'Home', 'ac_unit_rounded', 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400', 200, 500, 4.7, 7, true),
  ('cleaning', 'Cleaning', 'Home', 'cleaning_services_rounded', 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400', 150, 350, 4.8, 8, true),
  ('car_wash', 'Car Wash', 'Vehicle', 'local_car_wash_rounded', 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=400', 200, 400, 4.7, 9, true),
  ('bike_mechanic', 'Bike mechanic', 'Vehicle', 'two_wheeler_rounded', 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=400', 150, 350, 4.6, 10, true),
  ('hair_salon', 'Hair Salon', 'Beauty', 'content_cut_rounded', 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400', 150, 300, 4.8, 11, true),
  ('spa_massage', 'Spa & Massage', 'Beauty', 'spa_rounded', 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400', 300, 800, 4.9, 12, true),
  ('water_leakage', 'Water Leakage', 'Emergency', 'water_damage', 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=400', 300, 800, 4.9, 13, true),
  ('power_outage', 'Power Outage', 'Emergency', 'power_off', 'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=400', 300, 800, 4.9, 14, true),
  ('locked_out_of_home', 'Locked Out Of Home', 'Emergency', 'lock', 'https://images.unsplash.com/photo-1507208773393-40d9fc670acf?w=400', 300, 800, 4.9, 15, true),
  ('blocked_toilet_drain', 'Blocked Toilet/Drain', 'Emergency', 'plumbing', 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400', 300, 800, 4.9, 16, true),
  ('water_pump_failure', 'Water Pump Failure', 'Emergency', 'settings', 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400', 300, 800, 4.9, 17, true),
  ('ac_breakdown', 'AC Breakdown', 'Emergency', 'ac_unit', 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400', 300, 800, 4.9, 18, true),
  ('electrical_short_circuit', 'Electrical Short Circuit', 'Emergency', 'bolt', 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400', 300, 800, 4.9, 19, true),
  ('emergency_plumbing', 'Emergency Plumbing', 'Emergency', 'plumbing', 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400', 300, 800, 4.9, 20, true),
  ('emergency_electrician', 'Emergency Electrician', 'Emergency', 'electrical_services', 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400', 300, 800, 4.9, 21, true)
ON CONFLICT (id) DO NOTHING;


-- ════════════════════════════════════════════════════════════════
-- 2. PLATFORM_CONFIG TABLE
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS platform_config (
  id INTEGER PRIMARY KEY DEFAULT 1,
  surge_fee DECIMAL(8,2) DEFAULT 50.0,
  dispatch_radius_km DECIMAL(6,2) DEFAULT 5.0,
  expanded_radius_km DECIMAL(6,2) DEFAULT 10.0,
  sms_mode TEXT DEFAULT 'sandbox',
  websockets_sync BOOLEAN DEFAULT true,
  system_load TEXT DEFAULT 'optimal',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by TEXT
);

-- Seed the single config row
INSERT INTO platform_config (id, surge_fee, dispatch_radius_km, expanded_radius_km, sms_mode, websockets_sync, system_load)
VALUES (1, 50.0, 5.0, 10.0, 'sandbox', true, 'optimal')
ON CONFLICT (id) DO NOTHING;
