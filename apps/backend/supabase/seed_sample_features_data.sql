-- ============================================================================
-- JUGAAD APP: Non-Destructive Sample Data for 7 Marketplace Innovations
-- ============================================================================
-- NOTE: This script DOES NOT erase or overwrite any existing records!
-- It safely attaches sample items to your latest existing job,
-- or creates an isolated sample job row if none exists yet.
-- ============================================================================

DO $$
DECLARE
  v_job_id UUID;
  v_worker_id VARCHAR(128);
  v_employer_id VARCHAR(128);
BEGIN
  -- 1. Try to find the latest active job in your database
  SELECT id, worker_id, employer_id INTO v_job_id, v_worker_id, v_employer_id 
  FROM jobs 
  ORDER BY created_at DESC 
  LIMIT 1;

  -- 2. If no employer or worker found, safely pick or create demo user accounts
  IF v_employer_id IS NULL THEN
    SELECT id INTO v_employer_id FROM users WHERE role = 'employer' LIMIT 1;
    IF v_employer_id IS NULL THEN
      SELECT id INTO v_employer_id FROM users LIMIT 1;
    END IF;
    IF v_employer_id IS NULL THEN
      INSERT INTO users (id, phone, name, role) 
      VALUES ('demo_employer_kushal', '+919876543210', 'Kushal M N', 'employer')
      ON CONFLICT (id) DO NOTHING;
      v_employer_id := 'demo_employer_kushal';
    END IF;
  END IF;

  IF v_worker_id IS NULL THEN
    SELECT id INTO v_worker_id FROM workers LIMIT 1;
    IF v_worker_id IS NULL THEN
      SELECT id INTO v_worker_id FROM users WHERE role = 'worker' LIMIT 1;
    END IF;
    IF v_worker_id IS NULL THEN
      INSERT INTO users (id, phone, name, role) 
      VALUES ('demo_worker_ramesh', '+919876543211', 'Ramesh Kumar (4.9★ KYC Verified)', 'worker')
      ON CONFLICT (id) DO NOTHING;

      INSERT INTO workers (id, name, phone, skills, is_available, is_online)
      VALUES ('demo_worker_ramesh', 'Ramesh Kumar', '+919876543211', ARRAY['electrician'], true, true)
      ON CONFLICT (id) DO NOTHING;
      v_worker_id := 'demo_worker_ramesh';
    END IF;
  END IF;

  -- 3. If no job existed at all, create an isolated sample job
  IF v_job_id IS NULL THEN
    INSERT INTO jobs (
      id,
      employer_id,
      worker_id,
      skill_required,
      title,
      description,
      status,
      amount,
      agreed_price,
      before_photo_url,
      after_photo_url,
      is_scope_upgraded,
      scope_upgrade_name,
      scope_upgrade_amount,
      is_emergency,
      emergency_surcharge,
      created_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000001'::uuid,
      v_employer_id,
      v_worker_id,
      'electrician',
      'Electrical Spark & Wiring Repair',
      'Spark in main circuit board and humming noise at 24 degrees',
      'in_progress',
      550.00,
      550.00,
      'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800&auto=format&fit=crop&q=80',
      true,
      'Main Distribution MCB Overhaul',
      200.00,
      true,
      150.00,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      before_photo_url = COALESCE(jobs.before_photo_url, EXCLUDED.before_photo_url),
      after_photo_url = COALESCE(jobs.after_photo_url, EXCLUDED.after_photo_url)
    RETURNING id INTO v_job_id;
  ELSE
    -- If existing job exists, attach sample Before & After photos ONLY IF currently null
    UPDATE jobs
    SET before_photo_url = COALESCE(before_photo_url, 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80'),
        after_photo_url = COALESCE(after_photo_url, 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800&auto=format&fit=crop&q=80'),
        is_scope_upgraded = COALESCE(is_scope_upgraded, true),
        scope_upgrade_name = COALESCE(scope_upgrade_name, 'Main Distribution MCB Overhaul'),
        scope_upgrade_amount = COALESCE(scope_upgrade_amount, 200.00),
        is_emergency = COALESCE(is_emergency, true),
        emergency_surcharge = COALESCE(emergency_surcharge, 150.00)
    WHERE id = v_job_id;
  END IF;

  -- ─────────────────────────────────────────────────────────────────────────
  -- 4. INSERT 4 SAMPLE SPARE PARTS (Receipt Escrow)
  -- ─────────────────────────────────────────────────────────────────────────
  -- Item 1: Havells MCB (Pending customer approval)
  INSERT INTO spare_parts (
    id, job_id, worker_id, item_name, amount, receipt_photo_url, status, created_at
  ) VALUES (
    '11111111-1111-1111-1111-111111111111'::uuid,
    v_job_id,
    v_worker_id,
    'Havells 32A Double Pole MCB Switch',
    380.00,
    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&auto=format&fit=crop&q=80',
    'pending',
    NOW() - INTERVAL '10 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- Item 2: Finolex Wire (Approved)
  INSERT INTO spare_parts (
    id, job_id, worker_id, item_name, amount, receipt_photo_url, status, created_at, approved_at
  ) VALUES (
    '22222222-2222-2222-2222-222222222222'::uuid,
    v_job_id,
    v_worker_id,
    'Finolex 2.5mm Flameguard Wire Coil (5m)',
    420.00,
    'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
    'approved',
    NOW() - INTERVAL '25 minutes',
    NOW() - INTERVAL '20 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- Item 3: Supreme Ball Valve (Approved)
  INSERT INTO spare_parts (
    id, job_id, worker_id, item_name, amount, receipt_photo_url, status, created_at, approved_at
  ) VALUES (
    '33333333-3333-3333-3333-333333333333'::uuid,
    v_job_id,
    v_worker_id,
    'Supreme 1-inch Heavy PVC Ball Valve',
    450.00,
    'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&auto=format&fit=crop&q=80',
    'approved',
    NOW() - INTERVAL '40 minutes',
    NOW() - INTERVAL '35 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- Item 4: Anchor Roma Modular Socket (Approved)
  INSERT INTO spare_parts (
    id, job_id, worker_id, item_name, amount, receipt_photo_url, status, created_at, approved_at
  ) VALUES (
    '44444444-4444-4444-4444-444444444444'::uuid,
    v_job_id,
    v_worker_id,
    'Anchor Roma 16A Modular Socket & Switch Plate',
    190.00,
    'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
    'approved',
    NOW() - INTERVAL '55 minutes',
    NOW() - INTERVAL '50 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- ─────────────────────────────────────────────────────────────────────────
  -- 5. INSERT 4 SAMPLE VERNACULAR VOICE NOTES IN CHAT
  -- ─────────────────────────────────────────────────────────────────────────
  -- Note 1: Customer describes strange appliance sound (Voice Note)
  INSERT INTO messages (
    id, job_id, sender_id, text, voice_url, voice_duration_seconds, message_type, created_at
  ) VALUES (
    'aaaa1111-1111-1111-1111-111111111111'::uuid,
    v_job_id,
    v_employer_id,
    'Bhaiya, main switch board se strange spark aur humming noise aa raha hai 24 degrees pe.',
    'https://jugaad.internal/audio/sample_ac_humming.m4a',
    8,
    'voice',
    NOW() - INTERVAL '18 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- Note 2: Worker vernacular reply (Voice Note)
  INSERT INTO messages (
    id, job_id, sender_id, text, voice_url, voice_duration_seconds, message_type, created_at
  ) VALUES (
    'bbbb2222-2222-2222-2222-222222222222'::uuid,
    v_job_id,
    v_worker_id,
    'Sir, main 5 minute mein gate pe hoon, aap please main valve band kar lijiye.',
    'https://jugaad.internal/audio/sample_worker_arrival.m4a',
    6,
    'voice',
    NOW() - INTERVAL '14 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- Note 3: Worker informs about hardware receipt (Voice Note)
  INSERT INTO messages (
    id, job_id, sender_id, text, voice_url, voice_duration_seconds, message_type, created_at
  ) VALUES (
    'cccc3333-3333-3333-3333-333333333333'::uuid,
    v_job_id,
    v_worker_id,
    'Havells 32A MCB burnt tha sir, hardware shop se naya leke bill attach kar diya hai.',
    'https://jugaad.internal/audio/sample_part_bought.m4a',
    7,
    'voice',
    NOW() - INTERVAL '8 minutes'
  ) ON CONFLICT (id) DO NOTHING;

  -- Note 4: Customer approval confirmation (Voice Note)
  INSERT INTO messages (
    id, job_id, sender_id, text, voice_url, voice_duration_seconds, message_type, created_at
  ) VALUES (
    'dddd4444-4444-4444-4444-444444444444'::uuid,
    v_job_id,
    v_employer_id,
    'Thanks Ramesh! Escrow approval kar diya hai, finish hone ke baad check karte hain.',
    'https://jugaad.internal/audio/sample_customer_ack.m4a',
    5,
    'voice',
    NOW() - INTERVAL '4 minutes'
  ) ON CONFLICT (id) DO NOTHING;

END $$;
