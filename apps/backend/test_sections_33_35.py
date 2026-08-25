import sys

try:
    from shared.models import JobRespondRequest, JobCancelRequest, FCMTokenUpdate
    print("SUCCESS: shared.models imported respond, cancel, and fcm_token models successfully!")
except Exception as e:
    print(f"FAILED to import shared.models: {e}")
    sys.exit(1)

try:
    from routers.jobs import respond_to_job_request, timeout_check_job_request, cancel_job_request, get_job_request_status
    print("SUCCESS: routers.jobs imported respond, timeout_check, cancel, and get_job_request_status endpoints successfully!")
except Exception as e:
    print(f"FAILED to import routers.jobs: {e}")
    sys.exit(1)

try:
    from routers.workers import update_worker_fcm_token
    from routers.users import update_my_fcm_token
    print("SUCCESS: workers and users routers imported FCM token update endpoints successfully!")
except Exception as e:
    print(f"FAILED to import workers/users FCM endpoints: {e}")
    sys.exit(1)
