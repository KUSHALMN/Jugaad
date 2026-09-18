#!/usr/bin/env python3
"""
Jugaad App Unified Runner
Starts both Backend and Frontend with a single command.

Usage:
    python run_all.py                 # Backend + Flutter Mobile App (default)
    python run_all.py --web           # Backend + Admin Web Dashboard (Vite)
    python run_all.py --all           # Backend + Mobile App + Admin Web
    python run_all.py --backend-only  # Backend only
    python run_all.py -w              # Open in separate console windows
"""

import os
import sys
import time
import signal
import subprocess
import argparse
import threading

# Resolve repository root whether invoked from root or from within apps/
current_dir = os.path.dirname(os.path.abspath(__file__))
if os.path.exists(os.path.join(current_dir, "apps")):
    ROOT_DIR = current_dir
elif os.path.exists(os.path.join(current_dir, "..", "..", "apps")):
    ROOT_DIR = os.path.abspath(os.path.join(current_dir, "..", ".."))
elif os.path.exists(os.path.join(current_dir, "..", "apps")):
    ROOT_DIR = os.path.abspath(os.path.join(current_dir, ".."))
else:
    ROOT_DIR = current_dir

BACKEND_DIR = os.path.join(ROOT_DIR, "apps", "backend")
MOBILE_DIR = os.path.join(ROOT_DIR, "apps", "mobile")
ADMIN_DIR = os.path.join(ROOT_DIR, "apps", "admin")

processes = []

def print_banner(mode_str):
    print("=" * 60)
    print("   JUGAAD APP — UNIFIED LOCAL DEVELOPMENT RUNNER")
    print("=" * 60)
    print(f"  Mode:           {mode_str}")
    print("  Backend API:    http://localhost:8000")
    print("  API Docs:       http://localhost:8000/docs")
    print("  Health Check:   http://localhost:8000/health")
    print("=" * 60)
    print("  Press Ctrl+C at any time to cleanly stop all services.")
    print("=" * 60 + "\n")

def stream_logs(process, prefix, color_code):
    """Stream process stdout/stderr with a colored tag."""
    reset_code = "\033[0m"
    try:
        for line in iter(process.stdout.readline, ""):
            if not line:
                break
            line_str = line.rstrip()
            if line_str:
                print(f"{color_code}[{prefix}]{reset_code} {line_str}")
    except (ValueError, UnicodeDecodeError):
        pass

def kill_all_processes(signum=None, frame=None):
    print("\n\nShutting down all services...")
    for p in processes:
        if p.poll() is None:
            try:
                if sys.platform == "win32":
                    subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
                else:
                    p.terminate()
            except Exception:
                pass
    print("All services stopped.")
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(description="Run Jugaad Backend and Frontend simultaneously")
    parser.add_argument("--web", action="store_true", help="Run Admin Web (Vite) instead of Flutter mobile")
    parser.add_argument("--all", action="store_true", help="Run Backend, Flutter Mobile, AND Admin Web")
    parser.add_argument("--backend-only", action="store_true", help="Run only Backend")
    parser.add_argument("-d", "--device", type=str, default="", help="Target Flutter device (e.g. chrome, windows, android)")
    parser.add_argument("-i", "--inline", action="store_true", help="Stream all logs in the same terminal instead of separate windows")
    args = parser.parse_args()

    signal.signal(signal.SIGINT, kill_all_processes)
    signal.signal(signal.SIGTERM, kill_all_processes)

    run_mobile = not args.backend_only and (not args.web or args.all)
    run_web = args.web or args.all

    mode_parts = ["FastAPI Backend"]
    if run_mobile:
        mode_parts.append("Flutter Mobile App")
    if run_web:
        mode_parts.append("Admin Web (React/Vite)")
    mode_str = " + ".join(mode_parts)

    print_banner(mode_str)

    # On Windows, launch in dedicated windows by default unless --inline is specified
    use_windows = (sys.platform == "win32") and not args.inline

    if use_windows:
        print("[1/2] Launching FastAPI Backend in dedicated window...")
        cmd_backend = f'start "Jugaad Backend API (Port 8000)" cmd /k "cd /d {BACKEND_DIR} && python main.py"'
        os.system(cmd_backend)

        time.sleep(2)

        if run_web:
            print("[2/3] Launching Admin Web in dedicated window...")
            cmd_admin = f'start "Jugaad Admin Web (Port 5173)" cmd /k "cd /d {ADMIN_DIR} && npm run dev"'
            os.system(cmd_admin)

        if run_mobile:
            target_dev = args.device if args.device else "chrome"
            print(f"[2/2] Launching Flutter Mobile (-d {target_dev}) in dedicated window...")
            cmd_mobile = f'start "Jugaad Flutter Mobile" cmd /k "cd /d {MOBILE_DIR} && flutter run -d {target_dev}"'
            os.system(cmd_mobile)

        print("\n" + "=" * 60)
        print("  [SUCCESS] Both Backend and Frontend are now RUNNING!")
        print("  - Backend API:    http://localhost:8000 (Swagger docs at /docs)")
        print(f"  - Flutter Mobile: Compiling on '{target_dev}' in dedicated window")
        print("    (You can press 'r' to hot-reload in the Flutter window)")
        if run_web:
            print("  - Admin Web:      http://localhost:5173")
        print("=" * 60 + "\n")
        return

    # In-terminal process management with log streaming
    # 1. Start Backend
    print("--> [Starting] FastAPI Backend on port 8000...")
    backend_proc = subprocess.Popen(
        [sys.executable, "main.py"],
        cwd=BACKEND_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    processes.append(backend_proc)
    threading.Thread(target=stream_logs, args=(backend_proc, "BACKEND", "\033[94m"), daemon=True).start()

    time.sleep(1.5)

    # 2. Start Admin Web if requested
    if run_web:
        print("--> [Starting] Admin Web (Vite)...")
        npm_cmd = "npm.cmd" if sys.platform == "win32" else "npm"
        admin_proc = subprocess.Popen(
            [npm_cmd, "run", "dev"],
            cwd=ADMIN_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        processes.append(admin_proc)
        threading.Thread(target=stream_logs, args=(admin_proc, "ADMIN-WEB", "\033[95m"), daemon=True).start()

    # 3. Start Flutter Mobile if requested
    if run_mobile:
        flutter_cmd = "flutter.bat" if sys.platform == "win32" else "flutter"
        target_dev = args.device if args.device else "chrome"
        flutter_args = [flutter_cmd, "run", "-d", target_dev]

        print(f"--> [Starting] Flutter Mobile ({' '.join(flutter_args)})...")
        mobile_proc = subprocess.Popen(
            flutter_args,
            cwd=MOBILE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        processes.append(mobile_proc)
        threading.Thread(target=stream_logs, args=(mobile_proc, "MOBILE", "\033[92m"), daemon=True).start()

    # Keep orchestrator alive
    try:
        while True:
            time.sleep(0.5)
            # Check if any critical process died prematurely
            for p in processes:
                if p.poll() is not None:
                    print(f"\n[Warning] Process with PID {p.pid} exited with code {p.returncode}")
    except KeyboardInterrupt:
        kill_all_processes()

if __name__ == "__main__":
    main()
