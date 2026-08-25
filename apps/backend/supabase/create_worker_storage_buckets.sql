-- Migration: Create Storage Buckets for Worker Photos and Aadhaar Card Documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('worker-documents', 'worker-documents', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('worker-photos', 'worker-photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('worker-verification', 'worker-verification', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Public Read worker buckets" ON storage.objects;
CREATE POLICY "Public Read worker buckets" ON storage.objects
  FOR SELECT TO public USING (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));

DROP POLICY IF EXISTS "Public Upload worker buckets" ON storage.objects;
CREATE POLICY "Public Upload worker buckets" ON storage.objects
  FOR INSERT TO public WITH CHECK (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));

DROP POLICY IF EXISTS "Public Update worker buckets" ON storage.objects;
CREATE POLICY "Public Update worker buckets" ON storage.objects
  FOR UPDATE TO public USING (bucket_id IN ('worker-documents', 'worker-photos', 'worker-verification'));
