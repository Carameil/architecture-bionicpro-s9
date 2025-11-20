"""Authentication logic for BionicPRO Auth Service"""
import httpx
from typing import Dict, Optional, Any
import logging
from urllib.parse import urlencode

from config import Config

logger = logging.getLogger(__name__)

class KeycloakAuth:
    """Keycloak authentication handler"""
    
    def __init__(self, config: Config):
        self.config = config
        self.client = httpx.Client(timeout=30.0)
    
    def exchange_code_for_tokens(
        self, 
        code: str, 
        redirect_uri: str,
        code_verifier: Optional[str] = None
    ) -> Dict[str, Any]:
        """Exchange authorization code for tokens (supports PKCE)"""
        
        token_data = {
            "grant_type": "authorization_code",
            "client_id": self.config.KEYCLOAK_CLIENT_ID,
            "client_secret": self.config.KEYCLOAK_CLIENT_SECRET,
            "code": code,
            "redirect_uri": redirect_uri
        }
        
        # Add PKCE code verifier if provided
        if code_verifier:
            token_data["code_verifier"] = code_verifier
            
        try:
            response = self.client.post(
                self.config.get_keycloak_token_url(),
                data=token_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            
            return response.json()
            
        except httpx.HTTPError as e:
            logger.error(f"Error exchanging code for tokens: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"Response content: {e.response.text}")
            raise
    
    def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """Refresh access token using refresh token"""
        
        token_data = {
            "grant_type": "refresh_token",
            "client_id": self.config.KEYCLOAK_CLIENT_ID,
            "client_secret": self.config.KEYCLOAK_CLIENT_SECRET,
            "refresh_token": refresh_token
        }
        
        try:
            response = self.client.post(
                self.config.get_keycloak_token_url(),
                data=token_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            
            return response.json()
            
        except httpx.HTTPError as e:
            logger.error(f"Error refreshing token: {e}")
            raise
    
    def get_user_info(self, access_token: str) -> Dict[str, Any]:
        """Get user information from Keycloak"""
        
        try:
            response = self.client.get(
                self.config.get_keycloak_userinfo_url(),
                headers={"Authorization": f"Bearer {access_token}"}
            )
            response.raise_for_status()
            
            return response.json()
            
        except httpx.HTTPError as e:
            logger.error(f"Error getting user info: {e}")
            raise
    
    def logout(self, refresh_token: str) -> bool:
        """Logout user from Keycloak"""
        
        logout_data = {
            "client_id": self.config.KEYCLOAK_CLIENT_ID,
            "client_secret": self.config.KEYCLOAK_CLIENT_SECRET,
            "refresh_token": refresh_token
        }
        
        try:
            response = self.client.post(
                self.config.get_keycloak_logout_url(),
                data=logout_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            
            return True
            
        except httpx.HTTPError as e:
            logger.error(f"Error logging out: {e}")
            return False
    
    def get_authorization_url(
        self, 
        redirect_uri: str,
        state: str,
        code_challenge: Optional[str] = None,
        code_challenge_method: str = "S256"
    ) -> str:
        """Build authorization URL for Keycloak (supports PKCE)"""
        
        params = {
            "client_id": self.config.KEYCLOAK_CLIENT_ID,
            "response_type": "code",
            "redirect_uri": redirect_uri,
            "state": state,
            "scope": "openid profile email"
        }
        
        # Add PKCE parameters if provided
        if code_challenge:
            params["code_challenge"] = code_challenge
            params["code_challenge_method"] = code_challenge_method
            
        # Use public URL for browser redirects
        auth_endpoint = f"{self.config.KEYCLOAK_PUBLIC_URL}/realms/{self.config.KEYCLOAK_REALM}/protocol/openid-connect/auth"
        return f"{auth_endpoint}?{urlencode(params)}"
    
    def introspect_token(self, token: str) -> Dict[str, Any]:
        """Introspect token to check if it's active"""
        
        introspect_data = {
            "token": token,
            "client_id": self.config.KEYCLOAK_CLIENT_ID,
            "client_secret": self.config.KEYCLOAK_CLIENT_SECRET
        }
        
        try:
            response = self.client.post(
                f"{self.config.KEYCLOAK_URL}/realms/{self.config.KEYCLOAK_REALM}/protocol/openid-connect/token/introspect",
                data=introspect_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            
            return response.json()
            
        except httpx.HTTPError as e:
            logger.error(f"Error introspecting token: {e}")
            raise
    
    def __del__(self):
        """Cleanup HTTP client"""
        if hasattr(self, 'client'):
            self.client.close()
