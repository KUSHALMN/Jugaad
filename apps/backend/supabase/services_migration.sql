-- ============================================
-- JUGAAD MVP — Services Catalog Migration
-- Run this in Supabase SQL Editor
-- ============================================

-- Create services table
CREATE TABLE IF NOT EXISTS services (
  id VARCHAR(50) PRIMARY KEY,            -- e.g. "laptop_repair"
  title VARCHAR(100) NOT NULL,           -- e.g. "Laptop Repair"
  category VARCHAR(50) NOT NULL,         -- e.g. "Tech", "Home", "Vehicle", "Beauty"
  icon VARCHAR(100) DEFAULT '',          -- Flutter icon name (for fallback)
  image_url TEXT DEFAULT '',             -- Unsplash / CDN URL
  price_min DECIMAL(10,2) DEFAULT 150,
  price_max DECIMAL(10,2) DEFAULT 350,
  rating DECIMAL(3,2) DEFAULT 4.8,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read access
DROP POLICY IF EXISTS "services_anonymous_read" ON services;
CREATE POLICY "services_anonymous_read" ON services
  FOR SELECT USING (true);

-- Seed services data
INSERT INTO services (id, title, category, icon, image_url, price_min, price_max, rating, sort_order)
VALUES
  ('electrician', 'Electrician', 'Home', 'electrical_services_rounded', 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400', 150.00, 350.00, 4.8, 1),
  ('plumber', 'Plumber', 'Home', 'plumbing_rounded', 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400', 150.00, 350.00, 4.7, 2),
  ('laptop_repair', 'Laptop repair', 'Tech', 'laptop_mac_rounded', 'https://images.unsplash.com/photo-1588702547954-4800f964702a?w=400', 200.00, 500.00, 4.9, 3),
  ('phone_repair', 'Phone repair', 'Tech', 'phone_android_rounded', 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400', 150.00, 400.00, 4.8, 4),
  ('carpenter', 'Carpenter', 'Home', 'carpenter_rounded', 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400', 180.00, 400.00, 4.6, 5),
  ('painter', 'Painter', 'Home', 'format_paint_rounded', 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?w=400', 250.00, 600.00, 4.8, 6),
  ('ac_service', 'AC service', 'Home', 'ac_unit_rounded', 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400', 200.00, 500.00, 4.7, 7),
  ('cleaning', 'Cleaning', 'Home', 'cleaning_services_rounded', 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400', 150.00, 350.00, 4.8, 8),
  ('car_wash', 'Car Wash', 'Vehicle', 'local_car_wash_rounded', 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=400', 200.00, 400.00, 4.7, 9),
  ('bike_mechanic', 'Bike mechanic', 'Vehicle', 'two_wheeler_rounded', 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=400', 150.00, 350.00, 4.6, 10),
  ('hair_salon', 'Hair Salon', 'Beauty', 'content_cut_rounded', 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400', 150.00, 300.00, 4.8, 11),
  ('spa_massage', 'Spa & Massage', 'Beauty', 'spa_rounded', 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400', 300.00, 800.00, 4.9, 12)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  category = EXCLUDED.category,
  icon = EXCLUDED.icon,
  image_url = EXCLUDED.image_url,
  price_min = EXCLUDED.price_min,
  price_max = EXCLUDED.price_max,
  rating = EXCLUDED.rating,
  sort_order = EXCLUDED.sort_order;
