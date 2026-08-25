# 🐳 Jugaad App Backend — Docker Guide

This guide describes how to run and develop the Jugaad App backend monolith locally using Docker and Docker Compose.

---

## 📋 Prerequisites

Ensure you have the following installed on your machine:
1. **Docker Desktop**: [Download here](https://www.docker.com/products/docker-desktop/)
2. **Firebase Credentials**: A valid `firebase-credentials.json` file in the `jugaad-backend` root directory.

---

## ⚙️ Setup & Configuration

1. **Copy the Environment Template**
   ```bash
   cp .env.example .env
   ```

2. **Configure your Environment Variables**
   Open the `.env` file and enter your actual secrets:
   * `SUPABASE_URL` & `SUPABASE_SERVICE_ROLE_KEY` (Cloud hosted Postgres/PostGIS)
   * `RAZORPAY_KEY_ID` & `RAZORPAY_KEY_SECRET`
   * `MSG91_AUTH_KEY` & `MSG91_TEMPLATE_ID`

3. **Verify Firebase Credentials**
   Ensure `firebase-credentials.json` is located in the root of the project. It will be mounted into the container automatically.

---

## 🚀 Docker Compose Commands

Docker Compose manages both the FastAPI application and the local Redis cache.

### 1. Build and Start Services (Development)
Build the image and launch the container cluster in the foreground (with hot reload active):
```bash
docker compose up --build
```
* Once started, the API will be available at: **`http://localhost:8000`**
* Interactive Swagger Docs are at: **`http://localhost:8000/docs`**

### 2. Run in Background (Detached Mode)
Run the services in the background:
```bash
docker compose up -d
```

### 3. Check Container Status
See which containers are currently running:
```bash
docker compose ps
```

### 4. Stop Services
Stop the containers, keeping your volume data intact:
```bash
docker compose down
```

### 5. Stop and Clean Volume Data
Stop the containers and delete the Redis persistent volume data (fresh start):
```bash
docker compose down -v
```

---

## 🔍 Debugging & Logs

### View Container Logs
Stream application logs in real-time:
```bash
docker compose logs -f
```

To see logs for the API service only:
```bash
docker compose logs -f api
```

### Access Container Shell
Open an interactive bash shell inside the running FastAPI container:
```bash
docker compose exec api bash
```

### Access Redis CLI
Connect directly to the running Redis container to inspect keys:
```bash
docker compose exec redis redis-cli
```
Example commands:
```redis
PING
KEYS *
GET job:xxxx:status
```

---

## 🛠️ Standalone Docker Commands (Without Compose)

If you need to test the production image standalone:

### Build Image
```bash
docker build -t jugaad-backend:latest .
```

### Run Container
```bash
docker run -p 8000:8000 --env-file .env -v "$(pwd)/firebase-credentials.json:/app/firebase-credentials.json" jugaad-backend:latest
```
