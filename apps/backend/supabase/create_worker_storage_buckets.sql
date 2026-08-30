-- Migration: Create Storage Buckets for Worker Photos and Aadhaar Card Documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('worker-documents', 'worker-documents', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('worker-photos', 'worker-photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('worker-verification', 'worker-verification', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Public Read worker buckets" ON storage.objects;
DROP POLICY IF EXISTS "Public Upload worker buckets" ON storage.objects;
DROP POLICY IF EXISTS "Public Update worker buckets" ON storage.objects;

-- Public photo read only for public avatar photos
CREATE POLICY "Public Read worker photos" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'worker-photos');

-- Restricted read for verification/documents: admin or document owner
CREATE POLICY "Restricted Read verification docs" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('worker-documents', 'worker-verification')
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid()::text AND users.role = 'admin')
    )
  );

-- Authenticated workers upload only to their own folder or public photos
CREATE POLICY "Authenticated Upload worker objects" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'worker-photos'
    OR (
      bucket_id IN ('worker-documents', 'worker-verification')
      AND (storage.foldername(name))[1] = auth.uid()::text
    )
  );

