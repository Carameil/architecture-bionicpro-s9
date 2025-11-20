"""Main FastAPI application for BionicPRO Auth Service"""
import logging
import secrets
from typing import Optional
from datetime import datetime

from fastapi import FastAPI, Request, Response, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel

from config import Config
from auth import KeycloakAuth
from session import SessionManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="BionicPRO Auth Service",
    description="Backend for Frontend authentication service for BionicPRO",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=Config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
keycloak_auth = KeycloakAuth(Config)
session_manager = SessionManager(Config.SESSION_LIFETIME_MINUTES)

# Models
class LoginRequest(BaseModel):
    redirect_uri: str
    code_challenge: Optional[str] = None

class CallbackRequest(BaseModel):
    code: str
    state: str
    redirect_uri: str
    code_verifier: Optional[str] = None

class UserInfoResponse(BaseModel):
    sub: str
    name: str
    preferred_username: str
    email: Optional[str] = None
    roles: list = []

# Dependency to get current session
async def get_current_session(request: Request) -> Optional[dict]:
    """Get current session from cookie"""
    session_id = request.cookies.get(Config.COOKIE_NAME)
    if not session_id:
        return None
    
    session = session_manager.get_session(session_id)
    if not session:
        return None
    
    # Check if we need to refresh token
    if session_manager.is_token_expired(session_id):
        try:
            # Refresh the token
            token_response = keycloak_auth.refresh_access_token(session["refresh_token"])
            session_manager.update_tokens(
                session_id,
                access_token=token_response["access_token"],
                refresh_token=token_response.get("refresh_token", session["refresh_token"]),
                expires_in=token_response.get("expires_in", Config.ACCESS_TOKEN_LIFETIME_SECONDS)
            )
            session = session_manager.get_session(session_id)
        except Exception as e:
            logger.error(f"Failed to refresh token: {e}")
            session_manager.delete_session(session_id)
            return None
    
    # Perform session rotation if enabled
    if Config.SESSION_ROTATION_ENABLED:
        user_agent = request.headers.get("User-Agent")
        client_ip = request.client.host if request.client else None
        
        new_session_id = session_manager.rotate_session(
            session_id,
            user_agent=user_agent,
            ip_address=client_ip
        )
        
        if new_session_id:
            # Update session ID in the session dict for the response
            session["new_session_id"] = new_session_id
    
    return session

# Routes
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "bionicpro-auth"
    }

@app.post("/api/auth/login")
async def login(request: LoginRequest):
    """Initiate login flow with Keycloak"""
    state = secrets.token_urlsafe(32)
    
    auth_url = keycloak_auth.get_authorization_url(
        redirect_uri=request.redirect_uri,
        state=state,
        code_challenge=request.code_challenge
    )
    
    return {
        "auth_url": auth_url,
        "state": state
    }

@app.post("/api/auth/callback")
async def callback(request: CallbackRequest, response: Response, req: Request):
    """Handle OAuth callback from Keycloak"""
    try:
        # Exchange code for tokens
        token_response = keycloak_auth.exchange_code_for_tokens(
            code=request.code,
            redirect_uri=request.redirect_uri,
            code_verifier=request.code_verifier
        )
        
        # Get user info
        user_info = keycloak_auth.get_user_info(token_response["access_token"])
        
        # Extract user roles from token or user info
        user_info["roles"] = user_info.get("realm_access", {}).get("roles", [])
        
        # Create session
        user_agent = req.headers.get("User-Agent")
        client_ip = req.client.host if req.client else None
        
        session_id = session_manager.create_session(
            user_info=user_info,
            access_token=token_response["access_token"],
            refresh_token=token_response["refresh_token"],
            expires_in=token_response.get("expires_in", Config.ACCESS_TOKEN_LIFETIME_SECONDS),
            user_agent=user_agent,
            ip_address=client_ip
        )
        
        # Set session cookie
        response.set_cookie(
            key=Config.COOKIE_NAME,
            value=session_id,
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=Config.COOKIE_SAMESITE,
            max_age=Config.SESSION_LIFETIME_MINUTES * 60,
            domain=Config.COOKIE_DOMAIN
        )
        
        return {
            "success": True,
            "user": {
                "sub": user_info["sub"],
                "name": user_info.get("name", ""),
                "username": user_info.get("preferred_username", ""),
                "email": user_info.get("email"),
                "roles": user_info["roles"]
            }
        }
        
    except Exception as e:
        logger.error(f"Callback error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/auth/userinfo")
async def get_user_info(session: dict = Depends(get_current_session), response: Response = None):
    """Get current user information"""
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    # Check if we need to update cookie after session rotation
    if "new_session_id" in session:
        response.set_cookie(
            key=Config.COOKIE_NAME,
            value=session["new_session_id"],
            httponly=Config.COOKIE_HTTPONLY,
            secure=Config.COOKIE_SECURE,
            samesite=Config.COOKIE_SAMESITE,
            max_age=Config.SESSION_LIFETIME_MINUTES * 60,
            domain=Config.COOKIE_DOMAIN
        )
    
    return UserInfoResponse(**session["user_info"])

@app.post("/api/auth/logout")
async def logout(request: Request, response: Response):
    """Logout user and delete session"""
    session_id = request.cookies.get(Config.COOKIE_NAME)
    
    if session_id:
        session = session_manager.get_session(session_id)
        if session:
            # Logout from Keycloak
            keycloak_auth.logout(session["refresh_token"])
            
        # Delete session
        session_manager.delete_session(session_id)
    
    # Delete cookie
    response.delete_cookie(
        key=Config.COOKIE_NAME,
        domain=Config.COOKIE_DOMAIN
    )
    
    return {"success": True, "message": "Logged out successfully"}

@app.get("/api/auth/check")
async def check_auth(session: dict = Depends(get_current_session)):
    """Check if user is authenticated"""
    return {
        "authenticated": session is not None,
        "user": session["user_info"]["preferred_username"] if session else None
    }

@app.get("/api/sessions/active")
async def get_active_sessions():
    """Get count of active sessions (for monitoring)"""
    return {
        "active_sessions": session_manager.get_active_sessions_count(),
        "timestamp": datetime.utcnow().isoformat()
    }

# Protected route example
@app.get("/api/protected")
async def protected_route(session: dict = Depends(get_current_session)):
    """Example of protected endpoint"""
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    return {
        "message": "This is a protected resource",
        "user": session["user_info"]["preferred_username"],
        "roles": session["user_info"].get("roles", [])
    }

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=Config.HOST,
        port=Config.PORT,
        reload=Config.DEBUG
    )
