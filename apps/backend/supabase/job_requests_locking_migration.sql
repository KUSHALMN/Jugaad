-- PostgreSQL Row-Locking Functions for Job Requests Accept/Reject & Timeout
-- Uses SELECT ... FOR UPDATE inside PL/pgSQL explicit transaction blocks.
-- Compatible with TEXT user_id and TEXT worker_id (Firebase UIDs)
--
-- FIX: Renamed 'code' to 'result_code' in all JSONB returns to avoid
-- Supabase PostgREST Python client crash (Pydantic treats 'code' key as API error).

CREATE OR REPLACE FUNCTION respond_to_job_request_tx(
  p_job_request_id UUID,
  p_worker_id TEXT,
  p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_worker RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_worker_name TEXT;
  v_worker_phone TEXT;
BEGIN
  -- 1. Row-level lock on job_requests (SELECT ... FOR UPDATE)
  SELECT * INTO v_job
  FROM job_requests
  WHERE id = p_job_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'error', 'result_code', 404, 'message', 'Job request not found.');
  END IF;

  -- Double-submit check: if already accepted by THIS worker, return success
  IF v_job.status = 'accepted' AND v_job.accepted_worker_id = p_worker_id THEN
    RETURN jsonb_build_object('status', 'success', 'result_code', 200, 'message', 'Job already accepted by you.');
  END IF;

  -- Conflict check: if status moved past pending/notifying
  IF v_job.status IN ('accepted', 'cancelled', 'rejected_all', 'expired') THEN
    RETURN jsonb_build_object('status', 'conflict', 'result_code', 409, 'message', 'This job is no longer available.');
  END IF;

  IF p_action = 'accept' THEN
    -- 2. Row-level lock on workers (SELECT ... FOR UPDATE)
    SELECT * INTO v_worker
    FROM workers
    WHERE id = p_worker_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'error', 'result_code', 404, 'message', 'Worker not found.');
    END IF;

    IF v_worker.is_available IS FALSE THEN
      RETURN jsonb_build_object('status', 'conflict', 'result_code', 409, 'message', 'Worker is currently busy on another job.');
    END IF;

    -- Update job_requests
    UPDATE job_requests
    SET status = 'accepted',
        accepted_worker_id = p_worker_id,
        accepted_at = v_now,
        updated_at = v_now
    WHERE id = p_job_request_id;

    -- Update notification attempt
    UPDATE job_notification_attempts
    SET status = 'accepted',
        responded_at = v_now
    WHERE job_request_id = p_job_request_id AND worker_id = p_worker_id;

    -- Mark worker as busy
    UPDATE workers
    SET is_available = FALSE,
        updated_at = v_now
    WHERE id = p_worker_id;

    v_worker_name := COALESCE(v_worker.name, 'Worker');
    v_worker_phone := COALESCE(v_worker.phone, '');

    RETURN jsonb_build_object(
      'status', 'success',
      'result_code', 200,
      'user_id', v_job.user_id,
      'worker_name', v_worker_name,
      'worker_phone', v_worker_phone,
      'message', 'Job accepted successfully.'
    );

  ELSIF p_action = 'reject' THEN
    UPDATE job_notification_attempts
    SET status = 'rejected',
        responded_at = v_now
    WHERE job_request_id = p_job_request_id AND worker_id = p_worker_id;

    RETURN jsonb_build_object(
      'status', 'rejected',
      'result_code', 200,
      'job_request_id', p_job_request_id,
      'message', 'Job offer rejected.'
    );
  ELSE
    RETURN jsonb_build_object('status', 'error', 'result_code', 400, 'message', 'Invalid action.');
  END IF;
END;
$$;


CREATE OR REPLACE FUNCTION timeout_check_job_request_tx(
  p_job_request_id UUID,
  p_worker_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_attempt RECORD;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  -- 1. Row-level lock on job_requests (SELECT ... FOR UPDATE)
  SELECT * INTO v_job
  FROM job_requests
  WHERE id = p_job_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_job.status NOT IN ('pending', 'notifying') THEN
    RETURN jsonb_build_object('status', 'ignored', 'reason', 'Job request state no longer notifying');
  END IF;

  IF p_worker_id IS NOT NULL THEN
    SELECT * INTO v_attempt
    FROM job_notification_attempts
    WHERE job_request_id = p_job_request_id AND worker_id = p_worker_id
    FOR UPDATE;

    IF FOUND AND v_attempt.status <> 'sent' THEN
      RETURN jsonb_build_object('status', 'ignored', 'reason', 'Attempt state is ' || v_attempt.status);
    END IF;

    UPDATE job_notification_attempts
    SET status = 'timed_out',
        responded_at = v_now
    WHERE job_request_id = p_job_request_id AND worker_id = p_worker_id;
  END IF;

  RETURN jsonb_build_object('status', 'timeout_processed', 'job_request_id', p_job_request_id);
END;
$$;
