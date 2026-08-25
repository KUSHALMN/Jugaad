"""
Jugaad Platform Pre-flight & Health Verification Script
Validates local configuration and project readiness.
"""

import sys
import os

def check_python_version():
    print(f"Checking Python version: {sys.version}")
    if sys.version_info < (3, 10):
        print("❌ Python 3.10+ is recommended.")
        return False
    print("✅ Python version verified.")
    return True

def check_structure():
    expected_paths = [
        "apps/backend/main.py",
        "apps/admin/package.json",
        "apps/mobile/pubspec.yaml",
        "docs/brain.md",
    ]
    all_ok = True
    for p in expected_paths:
        if os.path.exists(p):
            print(f"✅ Found: {p}")
        else:
            print(f"❌ Missing: {p}")
            all_ok = False
    return all_ok

def main():
    print("=" * 50)
    print("🚀 Running Jugaad System Pre-Flight Checks")
    print("=" * 50)
    v_ok = check_python_version()
    s_ok = check_structure()
    if v_ok and s_ok:
        print("\n🎉 All system pre-flight checks passed successfully!")
    else:
        print("\n⚠️ Some checks failed. Please inspect the output above.")

if __name__ == "__main__":
    main()
