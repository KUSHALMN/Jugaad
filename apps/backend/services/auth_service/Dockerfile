FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY shared /app/shared
COPY services/auth_service /app/services/auth_service
ENV PYTHONPATH=/app
CMD ["uvicorn", "services.auth_service.main:app", "--host", "0.0.0.0", "--port", "8080"]
