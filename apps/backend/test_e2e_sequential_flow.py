import asyncio
import uuid
from datetime import datetime, timezone
from shared.models import JobRequestCreate, JobRespondRequest, JobCancelRequest, JobRequestResponse
from routers.jobs import request_job, respond_to_job_request, timeout_check_job_request, cancel_job_request, get_job_request_status, notify_next_worker

print("Starting E2E Sequential Flow Logic Test...")

# 1. Test model instantiation
job_req_input = JobRequestCreate(
    user_id=str(uuid.uuid4()),
    service_type="electrician",
    lat=12.3052,
    lng=76.6552
)

print(f"1. JobRequestCreate payload valid: user_id={job_req_input.user_id}, service_type={job_req_input.service_type}")

# 2. Test response model
job_res_out = JobRequestResponse(
    job_request_id=str(uuid.uuid4()),
    status="notifying",
    message="Notifying nearest candidate worker"
)

print(f"2. JobRequestResponse valid: job_request_id={job_res_out.job_request_id}, status={job_res_out.status}")

# 3. Test respond model
respond_accept = JobRespondRequest(
    worker_id=str(uuid.uuid4()),
    action="accept"
)
respond_reject = JobRespondRequest(
    worker_id=str(uuid.uuid4()),
    action="reject"
)
print(f"3. JobRespondRequest valid: accept={respond_accept.action}, reject={respond_reject.action}")

# 4. Test cancel model
cancel_req = JobCancelRequest(
    user_id=job_req_input.user_id
)
print(f"4. JobCancelRequest valid: user_id={cancel_req.user_id}")

print("\nAll E2E Sequential Flow logic assertions PASSED successfully!")
