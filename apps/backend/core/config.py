from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    ENV: str = "local"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    
    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_URL: str = ""

    def model_post_init(self, __context):
        if not self.REDIS_URL:
            self.REDIS_URL = f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}"
    
    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    
    # Modes
    SMS_MODE: str = "fake"       # "fake" | "real"
    QUEUE_MODE: str = "local"    # "local" | "qstash"
    
    # JWT
    JWT_SECRET: str = "local_dev_secret_jugaad_2024"
    
    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://10.0.2.2:8000",
        "http://127.0.0.1:8000"
    ]
    
    class Config:
        env_file = ".env.local"
        extra = "ignore"
        case_sensitive = False
        
    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls,
        init_settings,
        env_settings,
        dotenv_settings,
        file_secret_settings,
    ):
        return (
            init_settings,
            dotenv_settings,
            file_secret_settings,
        )

settings = Settings()
