import sys
import os

try:
    from shared.models import JobRequestCreate, JobRequestResponse
    print("SUCCESS: shared.models imported JobRequestCreate and JobRequestResponse successfully!")
except Exception as e:
    print(f"FAILED to import shared.models: {e}")
    sys.exit(1)

try:
    from routers.jobs import request_job, notify_next_worker
    print("SUCCESS: routers.jobs imported request_job and notify_next_worker successfully!")
except Exception as e:
    print(f"FAILED to import routers.jobs: {e}")
    sys.exit(1)
