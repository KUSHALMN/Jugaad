-- SQL migration to restrict access to worker-verification storage bucket

-- Drop existing policies for SELECT on this bucket if they exist
DROP POLICY IF EXISTS "Allow admin read on worker-verification" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read on worker-verification" ON storage.objects;

-- Create policy to allow only users with role = 'admin' in public.users to SELECT (read) files in the 'worker-verification' bucket
CREATE POLICY "Allow admin read on worker-verification" ON storage.objects
  FOR SELECT
  TO authenticated, anon
  USING (
    bucket_id = 'worker-verification'
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()::text
        AND users.role::text = 'admin'
    )
  );

-- Drop existing INSERT policies for this bucket if they exist
DROP POLICY IF EXISTS "Allow upload to worker-verification" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated write on worker-verification" ON storage.objects;

-- Allow any authenticated user (workers registering) to upload (INSERT) files to 'worker-verification' bucket
CREATE POLICY "Allow upload to worker-verification" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'worker-verification'
  );
