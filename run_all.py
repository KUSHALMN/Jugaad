#!/usr/bin/env python3
"""
Jugaad App Unified Runner
Starts both Backend and Frontend with a single command.

Usage:
    python run_all.py                 # Backend + Flutter Mobile App (default)
    python run_all.py -d chrome       # Explicitly target Chrome
    python run_all.py -d android      # Target Android emulator/device
    python run_all.py --web           # Backend + Admin Web Dashboard (Vite)
    python run_all.py --all           # Backend + Mobile App + Admin Web
    python run_all.py --backend-only  # Backend only
    python run_all.py -w              # Open in separate console windows (default on Windows)
    python run_all.py -i              # Stream all logs inline in a single terminal
"""

import os
import sys
import time
import signal
import subprocess
import argparse
import threading
import urllib.request

# Resolve repository root whether invoked from outer root, inner root, or apps/
current_dir = os.path.dirname(os.path.abspath(__file__))
if os.path.exists(os.path.join(current_dir, "apps")):
    ROOT_DIR = current_dir
elif os.path.exists(os.path.join(current_dir, "jugaad app update", "apps")):
    ROOT_DIR = os.path.join(current_dir, "jugaad app update")
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

def get_backend_python():
    """Find the best Python executable containing dependencies."""
    candidates = [
        os.path.join(BACKEND_DIR, ".venv", "Scripts", "python.exe"),
        os.path.join(ROOT_DIR, "new_venv", "Scripts", "python.exe"),
        os.path.join(BACKEND_DIR, "venv", "Scripts", "python.exe"),
        sys.executable,
    ]
    for c in candidates:
        if os.path.isabs(c) and os.path.exists(c):
            return c
    return sys.executable or "python"

def wait_for_backend(url="http://127.0.0.1:8000/health", timeout=12):
    """Wait until FastAPI is responsive on localhost."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            with urllib.request.urlopen(url, timeout=1.0) as resp:
                if resp.status == 200:
                    return True
        except Exception:
            time.sleep(0.5)
    return False

def print_banner(mode_str, device_str=""):
    print("=" * 65)
    print("      JUGAAD APP — SINGLE COMMAND FULL-STACK RUNNER")
    print("=" * 65)
    print(f"  Mode:            {mode_str}")
    if device_str:
        print(f"  Flutter Device:  {device_str}")
    print("  Backend API:     http://localhost:8000")
    print("  API Docs:        http://localhost:8000/docs")
    print("  Health Check:    http://localhost:8000/health")
    print("=" * 65)
    print("  Tip: In Flutter window, press 'r' for hot reload, 'R' to restart.")
    print("=" * 65 + "\n")

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
    parser.add_argument("-d", "--device", type=str, default="chrome", help="Target Flutter device (default: chrome)")
    parser.add_argument("-w", "--windows", action="store_true", help="Open services in separate dedicated console windows")
    parser.add_argument("-i", "--inline", action="store_true", help="Stream all logs in the same terminal instead of separate windows")
    args = parser.parse_args()

    signal.signal(signal.SIGINT, kill_all_processes)
    signal.signal(signal.SIGTERM, kill_all_processes)

    run_mobile = not args.backend_only and (not args.web or args.all)
    run_web = args.web or args.all
    target_dev = args.device if args.device else "chrome"

    mode_parts = ["FastAPI Backend"]
    if run_mobile:
        mode_parts.append(f"Flutter Mobile ({target_dev})")
    if run_web:
        mode_parts.append("Admin Web (React/Vite)")
    mode_str = " + ".join(mode_parts)

    print_banner(mode_str, target_dev if run_mobile else "")

    backend_py = get_backend_python()
    print(f"[*] Detected Python environment: {backend_py}")

    # On Windows, launch in dedicated windows by default unless --inline is specified
    use_windows = (sys.platform == "win32") and not args.inline

    if use_windows:
        print("[1/2] Launching FastAPI Backend in dedicated window...")
        cmd_backend = f'start "Jugaad Backend API (Port 8000)" cmd /k "cd /d \"{BACKEND_DIR}\" && \"{backend_py}\" main.py"'
        os.system(cmd_backend)

        print("[*] Waiting for Backend to be ready on http://127.0.0.1:8000/health ...")
        is_ready = wait_for_backend(timeout=10)
        if is_ready:
            print("[OK] Backend is healthy and ready!")
        else:
            print("[!] Backend launched (waiting for initialization)...")

        if run_web:
            print("[2/3] Launching Admin Web (Vite) in dedicated window...")
            cmd_admin = f'start "Jugaad Admin Web (Port 5173)" cmd /k "cd /d \"{ADMIN_DIR}\" && npm run dev"'
            os.system(cmd_admin)

        # Clean up any legacy temp profile locks
        legacy_profile = os.path.join(os.environ.get("TEMP", "C:/temp"), "flutter_chrome_dev")
        if os.path.exists(legacy_profile):
            try:
                import shutil
                shutil.rmtree(legacy_profile, ignore_errors=True)
            except Exception:
                pass

        if run_mobile:
            is_web = target_dev in ("chrome", "edge", "web-server")
            if is_web:
                actual_dev = "web-server"
                extra_flags = " --web-port 3000 --web-hostname localhost"
            else:
                actual_dev = target_dev
                extra_flags = ""

            print(f"[2/2] Launching Flutter Mobile on '{target_dev}' in dedicated window...")
            cmd_mobile = f'start "Jugaad Flutter Mobile" cmd /k "cd /d \"{MOBILE_DIR}\" && flutter run -d {actual_dev}{extra_flags}"'
            os.system(cmd_mobile)

            if is_web:
                def open_web():
                    time.sleep(5)
                    try:
                        import webbrowser
                        webbrowser.open("http://localhost:3000")
                    except Exception:
                        pass
                threading.Thread(target=open_web, daemon=True).start()

        print("\n" + "=" * 65)
        print("  [SUCCESS] Both Backend and Frontend are now RUNNING!")
        print("  - Backend API:    http://localhost:8000 (Swagger docs: http://localhost:8000/docs)")
        if run_mobile:
            print(f"  - Flutter Mobile: http://localhost:3000 (Opening in {target_dev})...")
            print("                    (Press 'r' in Flutter window for instant Hot Reload)")
        if run_web:
            print("  - Admin Web:      http://localhost:5173")
        print("=" * 65 + "\n")
        return

    # In-terminal process management with log streaming
    # 1. Start Backend
    print("--> [Starting] FastAPI Backend on port 8000...")
    backend_proc = subprocess.Popen(
        [backend_py, "main.py"],
        cwd=BACKEND_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    processes.append(backend_proc)
    threading.Thread(target=stream_logs, args=(backend_proc, "BACKEND", "\033[94m"), daemon=True).start()

    print("--> Waiting for Backend health check...")
    wait_for_backend(timeout=10)

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
        is_web = target_dev in ("chrome", "edge", "web-server")
        if is_web:
            actual_dev = "web-server"
            flutter_args = [flutter_cmd, "run", "-d", actual_dev, "--web-port", "3000", "--web-hostname", "localhost"]
            def open_web_inline():
                time.sleep(5)
                try:
                    import webbrowser
                    webbrowser.open("http://localhost:3000")
                except Exception:
                    pass
            threading.Thread(target=open_web_inline, daemon=True).start()
        else:
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
            for p in processes:
                if p.poll() is not None:
                    print(f"\n[Warning] Process with PID {p.pid} exited with code {p.returncode}")
    except KeyboardInterrupt:
        kill_all_processes()

if __name__ == "__main__":
    main()
