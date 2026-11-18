# Security Policy

The Jugaad team takes platform security and consumer safety extremely seriously. This document outlines our responsible disclosure guidelines, credential protection protocols, and security standards.

---

## 1. Supported Versions
Security updates are applied to the `main` branch.

| Component | Version / Environment | Supported |
|---|---|---|
| Mobile App (`apps/mobile`) | Flutter 3.29+ / Android 10+ / iOS 15+ | ✅ |
| Backend Gateway (`apps/backend`) | Python 3.11+ / FastAPI | ✅ |
| Admin Dashboard (`apps/admin`) | React 18+ / Vite | ✅ |

---

## 2. Reporting a Vulnerability
If you discover a security issue or vulnerability within Jugaad (including auth flaws, escrow leakage, or KYC bypass):
1. **Do NOT** open a public issue on GitHub.
2. Email your findings directly to: **`security@jugaad.app`**
3. Include:
   - Detailed proof-of-concept steps
   - Affected endpoint or widget file
   - Impact assessment
4. Our security team will acknowledge receipt within **24 hours** and provide a patch within **72 hours**.

---

## 3. Data Protection Standards
- **Zero-Trust Escrow**: Customer funds are not released until the user provides the completion PIN.
- **Biometric Aadhaar Security**: Technician identity documents are encrypted at rest with AES-256 in dedicated private storage buckets.
- **HMAC Signature Verification**: All external payment webhooks enforce cryptographic signature checks to prevent replay attacks.
