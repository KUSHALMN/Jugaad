import os
import sys

# Forward directly to the root run_all.py
root_script = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "run_all.py"))
if os.path.exists(root_script):
    import subprocess
    sys.exit(subprocess.call([sys.executable, root_script] + sys.argv[1:]))
else:
    print(f"Error: Could not find root script at {root_script}")
    sys.exit(1)
