"""Configuration for BionicPRO Auth Service"""
import os
from typing import Optional

class Config:
    """Application configuration"""
    
    # Server settings
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "True").lower() == "true"
    
    # Security settings
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    SESSION_LIFETIME_MINUTES: int = int(os.getenv("SESSION_LIFETIME_MINUTES", "60"))
    SESSION_ROTATION_ENABLED: bool = True
    
    # CORS settings
    CORS_ORIGINS: list = [
        "http://localhost:3000",
        "http://frontend:3000",
    ]
    
    # Keycloak settings
    # Internal URL for backend-to-backend communication
    KEYCLOAK_URL: str = os.getenv("KEYCLOAK_URL", "http://keycloak:8080")
    # Public URL for browser redirects (must be accessible from user's browser)
    KEYCLOAK_PUBLIC_URL: str = os.getenv("KEYCLOAK_PUBLIC_URL", "http://localhost:8080")
    KEYCLOAK_REALM: str = os.getenv("KEYCLOAK_REALM", "reports-realm")
    KEYCLOAK_CLIENT_ID: str = os.getenv("KEYCLOAK_CLIENT_ID", "reports-frontend")
    KEYCLOAK_CLIENT_SECRET: str = os.getenv("KEYCLOAK_CLIENT_SECRET", "")
    
    # Token settings
    ACCESS_TOKEN_LIFETIME_SECONDS: int = 120  # 2 minutes as required
    
    # Cookie settings
    COOKIE_NAME: str = "bionicpro_session"
    COOKIE_SECURE: bool = os.getenv("COOKIE_SECURE", "False").lower() == "true"
    COOKIE_HTTPONLY: bool = True
    COOKIE_SAMESITE: str = "strict"
    COOKIE_DOMAIN: Optional[str] = os.getenv("COOKIE_DOMAIN", None)
    
    # Redis settings (for future use)
    REDIS_URL: Optional[str] = os.getenv("REDIS_URL", None)
    
    @classmethod
    def get_keycloak_openid_config_url(cls) -> str:
        """Get Keycloak OpenID configuration URL"""
        return f"{cls.KEYCLOAK_URL}/realms/{cls.KEYCLOAK_REALM}/.well-known/openid-configuration"
    
    @classmethod
    def get_keycloak_token_url(cls) -> str:
        """Get Keycloak token endpoint URL"""
        return f"{cls.KEYCLOAK_URL}/realms/{cls.KEYCLOAK_REALM}/protocol/openid-connect/token"
    
    @classmethod
    def get_keycloak_userinfo_url(cls) -> str:
        """Get Keycloak userinfo endpoint URL"""
        return f"{cls.KEYCLOAK_URL}/realms/{cls.KEYCLOAK_REALM}/protocol/openid-connect/userinfo"
    
    @classmethod
    def get_keycloak_logout_url(cls) -> str:
        """Get Keycloak logout endpoint URL"""
        return f"{cls.KEYCLOAK_URL}/realms/{cls.KEYCLOAK_REALM}/protocol/openid-connect/logout"
