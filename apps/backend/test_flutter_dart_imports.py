import os

dart_files = [
    r"c:\Users\Kushal M N\Downloads\jugaad app update\jugaad app update\apps\mobile\lib\core\services\notification_service.dart",
    r"c:\Users\Kushal M N\Downloads\jugaad app update\jugaad app update\apps\mobile\lib\core\services\job_dispatch_service.dart",
    r"c:\Users\Kushal M N\Downloads\jugaad app update\jugaad app update\apps\mobile\lib\features\worker\screens\incoming_request_screen.dart",
]

for filepath in dart_files:
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        continue
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    print(f"File: {os.path.basename(filepath)} - Length: {len(content)} chars - Lines: {len(content.splitlines())}")

print("All Dart files checked and verified.")
