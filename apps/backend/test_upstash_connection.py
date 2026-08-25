"""Quick Upstash Redis and QStash connection test."""
import os
from dotenv import load_dotenv

load_dotenv()

print("--- Testing Upstash Redis ---")
try:
    from upstash_redis import Redis
    redis_url = os.getenv("UPSTASH_REDIS_REST_URL")
    redis_token = os.getenv("UPSTASH_REDIS_REST_TOKEN")
    
    if not redis_url or not redis_token:
        print("[FAIL] Redis credentials not found in .env")
    else:
        redis = Redis(url=redis_url, token=redis_token)
        redis.set("test_key", "Hello from Jugaad Backend!")
        val = redis.get("test_key")
        if val == "Hello from Jugaad Backend!":
            print("[OK] Upstash Redis connected successfully!")
        else:
            print(f"[FAIL] Redis returned unexpected value: {val}")
except ImportError:
    print("[SKIP] upstash-redis package not installed.")
except Exception as e:
    print(f"[FAIL] Redis Connection Failed: {e}")

print("\n--- Testing Upstash QStash ---")
try:
    from qstash import QStash
    qstash_token = os.getenv("QSTASH_TOKEN")
    
    if not qstash_token:
        print("[FAIL] QStash token not found in .env")
    else:
        # We just initialize the client, QStash doesn't have a simple "ping" 
        # without actually publishing a message, but we can verify the token is loaded.
        client = QStash(qstash_token)
        print("[OK] Upstash QStash client initialized with token successfully!")
except ImportError:
    print("[SKIP] qstash package not installed.")
except Exception as e:
    print(f"[FAIL] QStash Client Initialization Failed: {e}")
