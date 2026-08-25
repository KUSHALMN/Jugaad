# Contributing to Jugaad

Thank you for your interest in contributing to **Jugaad**! We welcome contributions from developers, designers, and testers to help make hyperlocal services better for everyone.

---

## 📋 Code of Conduct
Please be respectful and constructive in all interactions. We strive to create an open and welcoming environment for everyone.

---

## 🛠️ Development Workflow

1. **Fork or Clone the Repository**:
   ```bash
   git clone https://github.com/KUSHALMN/Jugaad.git
   cd Jugaad
   ```

2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Code Standards**:
   - **Flutter / Dart**: Follow effective Dart guidelines, use Riverpod for state management, and ensure GoRouter redirect guards remain synchronous.
   - **FastAPI / Python**: Adhere to PEP 8, use Pydantic models for validation, and use async handlers for IO-bound operations.
   - **React / Admin Dashboard**: Use clean component decomposition and Tailwind CSS utilities.

4. **Testing Before Committing**:
   - Backend: Run verification scripts in `apps/backend/`.
   - Admin: Run `npm run build` in `apps/admin/`.
   - Mobile: Run `flutter analyze` in `apps/mobile/`.

5. **Commit Messages**:
   Use conventional commits:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation updates
   - `refactor:` for code restructuring
   - `ci:` for CI/CD pipeline changes

---

## 🚀 Submitting Pull Requests
- Open a PR against the `main` branch.
- Provide a clear summary of changes and attach screenshots or test logs where applicable.
