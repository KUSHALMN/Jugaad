# REPLACE google-cloud-logging with standard Python logging
# Render captures stdout automatically — no extra config needed

import logging
import sys

def setup_logging(service_name: str):
    logging.basicConfig(
        level=logging.INFO,
        format=f"%(asctime)s [{service_name}] %(levelname)s %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)]
    )
    return logging.getLogger(service_name)

# Backward-compatible log() function used across all services
def log(service: str, func: str, status: str, severity: str = "INFO", **kwargs):
    """
    Drop-in replacement for the old shared/logging.log() calls.
    Preserves the existing call signature so no service code changes needed.
    """
    logger = logging.getLogger(service)
    extra_str = " ".join(f"{k}={v}" for k, v in kwargs.items()) if kwargs else ""
    message = f"{func} {status} {extra_str}".strip()

    level = getattr(logging, severity.upper(), logging.INFO)
    logger.log(level, message)

# Usage in each service main.py:
# logger = setup_logging("matching_service")
# logger.info("Worker matched", extra={"job_id": job_id})
