"""Configuration for BionicPRO Reports Service"""

import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings"""
    
    # Service settings
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8002"))
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    
    # ClickHouse settings
    CLICKHOUSE_HOST: str = os.getenv("CLICKHOUSE_HOST", "clickhouse")
    CLICKHOUSE_PORT: int = int(os.getenv("CLICKHOUSE_PORT", "9000"))
    CLICKHOUSE_DATABASE: str = os.getenv("CLICKHOUSE_DATABASE", "bionicpro")
    CLICKHOUSE_USER: str = os.getenv("CLICKHOUSE_USER", "default")
    CLICKHOUSE_PASSWORD: str = os.getenv("CLICKHOUSE_PASSWORD", "")
    
    # BFF (Auth service) settings
    BFF_URL: str = os.getenv("BFF_URL", "http://bionicpro-auth:8000")
    BFF_VALIDATE_SESSION_ENDPOINT: str = "/api/auth/validate-session"
    
    # S3 (MinIO) settings - Assignment 3
    S3_ENDPOINT_URL: str = os.getenv("S3_ENDPOINT_URL", "http://minio:9000")
    S3_ACCESS_KEY: str = os.getenv("S3_ACCESS_KEY", "minioadmin")
    S3_SECRET_KEY: str = os.getenv("S3_SECRET_KEY", "minioadmin")
    S3_BUCKET_NAME: str = os.getenv("S3_BUCKET_NAME", "bionicpro-reports")
    S3_ENABLED: bool = os.getenv("S3_ENABLED", "True").lower() == "true"
    
    # CDN settings - Assignment 3
    CDN_BASE_URL: str = os.getenv("CDN_BASE_URL", "http://localhost:8090")
    
    # CORS settings
    CORS_ORIGINS: list = ["http://localhost:3000", "http://localhost:8000"]
    
    model_config = SettingsConfigDict(env_file=".env")


settings = Settings()
