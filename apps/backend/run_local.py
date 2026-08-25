import subprocess
import sys
import os
import time
from dotenv import load_dotenv

load_dotenv()

SERVICES = [
    ("request", "services.request_service.main:app", 8001),
    ("matching", "services.matching_service.main:app", 8002),
    ("notification", "services.notification_service.main:app", 8003),
    ("job", "services.job_service.main:app", 8004),
    ("worker", "services.worker_service.main:app", 8005),
    ("booking", "services.booking_service.main:app", 8006),
    ("payment", "services.payment_service.main:app", 8007),
    ("admin", "services.admin_service.main:app", 8008),
    ("review", "services.review_service.main:app", 8009),
    ("auth", "services.auth_service.main:app", 8010),
    ("user", "services.user_service.main:app", 8011),
    ("scheduler", "services.scheduler_service.main:app", 8012),
]

def main():
    print("Starting all microservices locally...")
    
    # Set up environment variables for the gateway to route correctly
    env = os.environ.copy()
    for name, _, port in SERVICES:
        env[f"{name.upper()}_SERVICE_URL"] = f"http://localhost:{port}"

    processes = []
    
    # 1. Start all backend microservices
    for name, module, port in SERVICES:
        print(f"Starting {name}-service on port {port}...")
        p = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", module, "--port", str(port)],
            env=env
        )
        processes.append(p)
        
    time.sleep(2) # Wait a bit before starting gateway
    
    # 2. Start the gateway on port 8081
    print("Starting gateway on port 8081...")
    gateway_p = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "gateway.main:app", "--port", "8081", "--reload"],
        env=env
    )
    processes.append(gateway_p)

    print("  All services started! Gateway is at http://localhost:8081")
    print("Press Ctrl+C to stop all services.")
    print("=======================================================\n")

    try:
        for p in processes:
            p.wait()
    except KeyboardInterrupt:
        print("\nShutting down all services...")
        for p in processes:
            p.terminate()
        for p in processes:
            p.wait()
        print("Shutdown complete.")

if __name__ == "__main__":
    main()
