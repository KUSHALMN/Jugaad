# shared/logging_config.py
"""
Structured JSON logger for Google Cloud Logging.
Outputs valid JSON to stdout — Cloud Run auto-captures as structured logs.
"""
import logging
import sys
from datetime import datetime, timezone

# Support python-json-logger v2.x (pythonjsonlogger) and v3.x (pythonjsonlogger.core)
# Also handle case where library is not installed (Docker will have it)
try:
    from pythonjsonlogger import jsonlogger
    _JsonFormatter = jsonlogger.JsonFormatter
except ImportError:
    try:
        from pythonjsonlogger.core import JsonFormatter as _JsonFormatter
    except ImportError:
        # Fallback: plain formatter that emits JSON-ish strings
        import json as _json

        class _JsonFormatter(logging.Formatter):  # type: ignore
            def format(self, record):
                log_obj = {
                    "message": record.getMessage(),
                    "severity": record.levelname,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
                log_obj.update(getattr(record, "extra_fields", {}))
                return _json.dumps(log_obj)


class JugaadJsonFormatter(_JsonFormatter):  # type: ignore
    def __init__(self, service_name: str):
        super().__init__(
            "%(timestamp)s %(severity)s %(service)s %(message)s %(job_id)s %(worker_id)s"
        )
        self.service_name = service_name

    def add_fields(self, log_record, record, message_dict):
        super().add_fields(log_record, record, message_dict)

        log_record["service"] = self.service_name
        log_record["timestamp"] = datetime.now(timezone.utc).isoformat()
        log_record["severity"] = record.levelname
        if "levelname" in log_record:
            del log_record["levelname"]

        log_record["message"] = record.getMessage()

        for key in ("job_id", "worker_id"):
            if hasattr(record, key):
                log_record[key] = getattr(record, key)
            elif key in message_dict:
                log_record[key] = message_dict[key]

            if key in log_record and log_record[key] is None:
                del log_record[key]


def get_logger(service_name: str) -> logging.Logger:
    """
    Return a logger that emits structured JSON lines to stdout.
    Safe to call multiple times — handlers are attached only once.
    """
    logger = logging.getLogger(service_name)
    logger.setLevel(logging.INFO)

    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = JugaadJsonFormatter(service_name)
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    logger.propagate = False
    return logger
