# 🔒 Security Policy & Safeguards

## Supported Versions
| Version | Supported |
| :--- | :--- |
| 1.2.x | :white_check_mark: |
| 1.1.x | :white_check_mark: |
| 1.0.x | :x: |

---

## 🛡️ Security Architecture

### 1. Zero Direct Client Mutations for Sensitive Columns
Worker verification status (`approval_status`, `id_verified`, `is_suspended`) cannot be modified directly from client SDKs. All state transitions must traverse authenticated backend endpoints that enforce admin privileges.

### 2. Row Level Security (RLS)
- Customer personal records and saved addresses are strictly isolated to the authenticated owner (`auth.uid() = user_id`).
- Private storage buckets holding Aadhaar identity documents allow read access exclusively to users with `role = 'admin'`.

### 3. Rate Limiting & Input Sanitization
- Spatial queries and public endpoints are throttled via Redis cache layers.
- API inputs are validated with Pydantic and parameterized SQL bindings to defend against SQL injections.

---

## 🚨 Reporting a Vulnerability
If you discover a security vulnerability, please email **kushalmn.dev@gmail.com** or open a private security advisory on GitHub.
