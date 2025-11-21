"""Authentication logic for BionicPRO Auth Service"""
import httpx
from typing import Dict, Optional, Any
import logging
from urllib.parse import urlencode
import base64
import json

from config import Config

logger = logging.getLogger(__name__)


def decode_jwt_payload(token: str) -> dict:
    """Decode JWT payload without verification (for debugging only)"""
    try:
        parts = token.split('.')
        if len(parts) != 3:
            return {}
        
        payload = parts[1]
        padding = 4 - len(payload) % 4
        if padding != 4:
            payload += '=' * padding
        
        decoded = base64.urlsafe_b64decode(payload)
        return json.loads(decoded)
    except Exception as e:
        logger.error(f"Error decoding JWT: {e}")
        return {}

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
            "code": code,
            "redirect_uri": redirect_uri
        }
        
        if self.config.KEYCLOAK_CLIENT_SECRET:
            token_data["client_secret"] = self.config.KEYCLOAK_CLIENT_SECRET
        
        if code_verifier:
            token_data["code_verifier"] = code_verifier
            
        try:
            response = self.client.post(
                self.config.get_keycloak_token_url(),
                data=token_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            response.raise_for_status()
            
            token_response = response.json()
            access_token = token_response.get('access_token', '')
            if access_token:
                payload = decode_jwt_payload(access_token)
                logger.info(f"Token payload - iss: {payload.get('iss')}, aud: {payload.get('aud')}, scope: {payload.get('scope')}, azp: {payload.get('azp')}")
                logger.info(f"Token payload - sub: {payload.get('sub')}, preferred_username: {payload.get('preferred_username')}")

            return token_response
            
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
            "refresh_token": refresh_token
        }
        
        if self.config.KEYCLOAK_CLIENT_SECRET:
            token_data["client_secret"] = self.config.KEYCLOAK_CLIENT_SECRET
        
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
        """Get user information from JWT access token (without userinfo endpoint call)"""
        
        try:
            logger.info(f"Extracting user info from JWT access token")
            
            # Decode JWT payload locally
            payload = decode_jwt_payload(access_token)
            
            if not payload:
                raise ValueError("Failed to decode JWT token")
            
            # Extract standard user info from JWT claims
            user_info = {
                "sub": payload.get("sub"),
                "preferred_username": payload.get("preferred_username"),
                "email": payload.get("email"),
                "email_verified": payload.get("email_verified", False),
                "name": payload.get("name"),
                "given_name": payload.get("given_name"),
                "family_name": payload.get("family_name"),
                "realm_access": payload.get("realm_access", {}),
                "resource_access": payload.get("resource_access", {})
            }
            
            logger.info(f"User info extracted: username={user_info.get('preferred_username')}, sub={user_info.get('sub')}")
            
            return user_info
            
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
