#!/usr/bin/env python3
"""
Flutter Auto-Reload Runner for Jugaad App
Runs Flutter connected to Chrome (or target device) with full Hot Reload
and an automatic file watcher on lib/.

Whenever any .dart file is edited/saved, it automatically sends 'r' to Flutter
so code changes reflect immediately on the running app.
You can also press 'r' manually for Hot Reload, 'R' for Hot Restart, or 'q' to quit.
"""
import os
import sys
import time
import subprocess
import threading
try:
    import msvcrt
except ImportError:
    msvcrt = None

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOBILE_DIR = os.path.join(ROOT_DIR, "apps", "mobile")
LIB_DIR = os.path.join(MOBILE_DIR, "lib")

def scan_files(directory):
    files = {}
    if not os.path.exists(directory):
        return files
    for root, _, filenames in os.walk(directory):
        for f in filenames:
            if f.endswith(".dart") or f.endswith(".yaml"):
                full_path = os.path.join(root, f)
                try:
                    files[full_path] = os.stat(full_path).st_mtime
                except OSError:
                    pass
    return files

def file_watcher(proc, watch_dir):
    time.sleep(3)  # Wait for initial build to stabilize
    last_files = scan_files(watch_dir)
    print(f"\n[⚡ Auto-Reload Active] Watching {watch_dir} for code changes...")
    print("                      Any saved changes in .dart files will auto-reload the app!\n")

    while proc.poll() is None:
        time.sleep(0.4)
        current_files = scan_files(watch_dir)
        changed_file = None
        for path, mtime in current_files.items():
            if path not in last_files or mtime > last_files[path] + 0.1:
                changed_file = path
                break
        if not changed_file:
            for path in last_files:
                if path not in current_files:
                    changed_file = path
                    break

        if changed_file:
            last_files = current_files
            rel_name = os.path.relpath(changed_file, watch_dir)
            print(f"\n[🔥 Auto-Reload] Code change detected in: {rel_name}")
            print("                 Triggering Flutter Hot Reload...")
            try:
                proc.stdin.write(b"r\n")
                proc.stdin.flush()
            except Exception:
                break
            time.sleep(1.0)  # Debounce to prevent multiple reloads on batch save

def keyboard_listener(proc):
    while proc.poll() is None:
        try:
            if msvcrt:
                ch = msvcrt.getch()
                if ch in (b'r', b'R', b'c', b'h', b'q', b'p'):
                    if ch == b'q':
                        try:
                            proc.stdin.write(b"q\n")
                            proc.stdin.flush()
                        except Exception:
                            pass
                        break
                    try:
                        proc.stdin.write(ch + b"\n")
                        proc.stdin.flush()
                    except Exception:
                        pass
            else:
                line = sys.stdin.readline()
                if not line:
                    break
                try:
                    proc.stdin.write(line.encode())
                    proc.stdin.flush()
                except Exception:
                    pass
        except Exception:
            break

def main():
    target_dev = sys.argv[1] if len(sys.argv) > 1 else "chrome"
    flutter_cmd = "flutter.bat" if sys.platform == "win32" else "flutter"

    # Clean legacy chrome lock if exists
    legacy_profile = os.path.join(os.environ.get("TEMP", "C:/temp"), "flutter_chrome_dev")
    if os.path.exists(legacy_profile):
        try:
            import shutil
            shutil.rmtree(legacy_profile, ignore_errors=True)
        except Exception:
            pass

    cmd = [flutter_cmd, "run", "-d", target_dev]
    if target_dev in ("chrome", "edge"):
        cmd.extend(["--web-port", "3000"])

    print("=" * 65)
    print("      JUGAAD FLUTTER RUNNER WITH INSTANT AUTO-RELOAD")
    print("=" * 65)
    print(f"  Target Device:   {target_dev}")
    print(f"  Directory:       {MOBILE_DIR}")
    print(f"  Watch Folder:    {LIB_DIR}")
    print("  Auto-Reload:     ENABLED (Auto-reloads on Ctrl+S / file save)")
    print("  Key Commands:    'r' = Reload, 'R' = Restart, 'q' = Quit")
    print("=" * 65 + "\n")

    proc = subprocess.Popen(
        cmd,
        cwd=MOBILE_DIR,
        stdin=subprocess.PIPE,
        bufsize=0
    )

    t_watch = threading.Thread(target=file_watcher, args=(proc, LIB_DIR), daemon=True)
    t_watch.start()

    t_keys = threading.Thread(target=keyboard_listener, args=(proc,), daemon=True)
    t_keys.start()

    try:
        proc.wait()
    except KeyboardInterrupt:
        try:
            proc.stdin.write(b"q\n")
            proc.stdin.flush()
        except Exception:
            pass
        proc.terminate()

if __name__ == "__main__":
    main()
