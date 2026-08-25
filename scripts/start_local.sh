#!/bin/bash
echo "🚀 Starting Jugaad App Local Dev Environment"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Start Redis
echo "📦 Starting Redis..."
docker compose -f "${SCRIPT_DIR}/../infrastructure/docker/docker-compose.yml" up -d

# Wait for Redis
sleep 2

# Start FastAPI
echo "⚡ Starting FastAPI on port 8000..."
cd "${SCRIPT_DIR}/../apps/backend"
pip install -r requirements.txt -q
python main.py &
BACKEND_PID=$!

echo ""
echo "════════════════════════════════════"
echo "✅ Jugaad Local Dev Ready!"
echo "════════════════════════════════════"
echo "  API:           http://localhost:8000"
echo "  API Docs:      http://localhost:8000/docs"
echo "  Health Check:  http://localhost:8000/health"
echo "  Redis UI:      http://localhost:8081"
echo "════════════════════════════════════"
echo "  Flutter: Run with Android Emulator"
echo "  Base URL set to: http://10.0.2.2:8000"
echo "════════════════════════════════════"
echo ""
echo "Press Ctrl+C to stop"

wait $BACKEND_PID
