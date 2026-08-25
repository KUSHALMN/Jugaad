# shared/firebase_init.py
"""
Firebase Admin SDK initialization — must be imported by every service
that uses Firebase Auth (verify_id_token) or FCM (messaging.send).

Import this module at the top of each service's main.py:
    import shared.firebase_init  # noqa: F401

Safe to import multiple times — initialize_app() is called only once.
"""
import os
import json
import firebase_admin
from firebase_admin import credentials

_initialized = False


def _init_firebase():
    global _initialized
    if _initialized or firebase_admin._apps:
        return

    # Option 1: Explicit credentials file path (local dev / Docker)
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    # Option 2: JSON string in env var (Render / serverless — preferred for cloud)
    cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON", "") or os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    # Option 3: Bundled credentials file (local dev fallback only)
    firebase_cred_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "firebase-credentials.json",
    )

    if cred_path and os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    elif cred_json:
        cred = credentials.Certificate(json.loads(cred_json))
        firebase_admin.initialize_app(cred)
    elif os.path.exists(firebase_cred_path):
        cred = credentials.Certificate(firebase_cred_path)
        firebase_admin.initialize_app(cred)
    else:
        raise RuntimeError(
            "Firebase credentials not found. Set GOOGLE_APPLICATION_CREDENTIALS "
            "(file path) or FIREBASE_CREDENTIALS_JSON (JSON string) env var."
        )

    _initialized = True


# Auto-initialize on import
_init_firebase()
