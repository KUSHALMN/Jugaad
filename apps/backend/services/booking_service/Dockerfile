FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY shared /app/shared
COPY routers /app/routers
COPY services /app/services
ENV PYTHONPATH=/app
CMD ["uvicorn", "services.booking_service.main:app", "--host", "0.0.0.0", "--port", "8080"]
