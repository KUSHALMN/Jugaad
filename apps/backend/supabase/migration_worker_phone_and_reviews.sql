-- Migration: Worker Phone Field, Reviews Indexing, and Aggregate Rating Trigger
-- Ensures reviews index and updated aggregate rating logic.

-- 1. Ensure phone column exists on workers table
ALTER TABLE workers ADD COLUMN IF NOT EXISTS phone VARCHAR(15);

-- 2. Index for reviews lookup by reviewee_id (worker_id)
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_reviews_job ON reviews(job_id);

-- 3. Atomic review submission and worker aggregate rating calculation RPC
CREATE OR REPLACE FUNCTION submit_review_atomic(
  p_job_id UUID,
  p_reviewer_id VARCHAR(128),
  p_reviewee_id VARCHAR(128),
  p_rating INT,
  p_comment TEXT
)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_new_rating DECIMAL;
BEGIN
  -- Insert or update review for this job
  INSERT INTO reviews(job_id, reviewer_id, reviewee_id, rating, comment)
  VALUES (p_job_id, p_reviewer_id, p_reviewee_id, p_rating, p_comment)
  ON CONFLICT (job_id) DO UPDATE SET
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment,
    created_at = NOW();

  -- Recalculate exact average rating of all reviews for this worker
  SELECT COALESCE(AVG(rating), 0.0) INTO v_new_rating
  FROM reviews WHERE reviewee_id = p_reviewee_id;

  -- Update worker aggregate rating
  UPDATE workers SET rating = ROUND(v_new_rating, 2)
  WHERE id = p_reviewee_id;
END;
$$;
