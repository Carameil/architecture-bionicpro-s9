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
async def get_current_session(request: Request, response: Response = None) -> Optional[dict]:
    """Get current session from cookie with automatic rotation handling"""
    session_id = request.cookies.get(Config.COOKIE_NAME)
    if not session_id:
        logger.warning(f"No session cookie '{Config.COOKIE_NAME}' found in request to {request.url.path}")
        return None
    
    session = session_manager.get_session(session_id)
    if not session:
        logger.warning(f"Session not found or expired for ID: {session_id[:10]}...")
        return None
        
    # Handle Grace Period: If user sent an old session ID that was recently rotated,
    # give them the new session ID in cookie!
    if session.get("is_rotated"):
        logger.info(f"Request with rotated session {session_id[:10]}... (Grace Period)")
        if "next_session_id" in session and response:
            response.set_cookie(
                key=Config.COOKIE_NAME,
                value=session["next_session_id"],
                httponly=Config.COOKIE_HTTPONLY,
                secure=Config.COOKIE_SECURE,
                samesite=Config.COOKIE_SAMESITE,
                max_age=Config.SESSION_LIFETIME_MINUTES * 60
            )
        return session
    
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
    
    # Perform session rotation if enabled (but only periodically, not on every request)
    if Config.SESSION_ROTATION_ENABLED:
        # Check if session should be rotated (based on time interval)
        from datetime import datetime, timedelta
        last_rotation_str = session.get("last_rotated_at") or session.get("created_at")
        
        should_rotate = False
        if last_rotation_str:
            try:
                last_rotation = datetime.fromisoformat(last_rotation_str)
                rotation_interval = timedelta(minutes=Config.SESSION_ROTATION_INTERVAL_MINUTES)
                if datetime.utcnow() - last_rotation >= rotation_interval:
                    should_rotate = True
            except:
                should_rotate = True  # Rotate if timestamp parsing fails
        else:
            should_rotate = True  # Rotate if no timestamp found
        
        if should_rotate:
            user_agent = request.headers.get("User-Agent")
            client_ip = request.client.host if request.client else None
            
            new_session_id = session_manager.rotate_session(
                session_id,
                user_agent=user_agent,
                ip_address=client_ip
            )
            
            if new_session_id:
                # Automatically set the new cookie if response is available!
                if response:
                    response.set_cookie(
                        key=Config.COOKIE_NAME,
                        value=new_session_id,
                        httponly=Config.COOKIE_HTTPONLY,
                        secure=Config.COOKIE_SECURE,
                        samesite=Config.COOKIE_SAMESITE,
                        max_age=Config.SESSION_LIFETIME_MINUTES * 60
                    )
                    session["new_session_id"] = new_session_id
                    logger.info(f"Session rotated: {session_id[:10]}... -> {new_session_id[:10]}...")
                else:
                    # Can't set cookie without Response, skip rotation for this request
                    logger.debug(f"Skipping session rotation (no Response object available)")
    
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
            max_age=Config.SESSION_LIFETIME_MINUTES * 60
            # domain=Config.COOKIE_DOMAIN  <- Removed to let browser handle localhost
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
async def get_user_info(session: dict = Depends(get_current_session)):
    """Get current user information"""
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
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

@app.post("/api/auth/validate-session")
async def validate_session(request: dict):
    """
    Validate session for internal service-to-service calls
    Used by other services (e.g., bionicpro-reports) to validate user sessions
    
    Args:
        request: {"session_id": "..."}
    
    Returns:
        User info if session is valid
    
    Raises:
        401 if session is invalid
    """
    session_id = request.get("session_id")
    
    if not session_id:
        raise HTTPException(status_code=401, detail="session_id required")
    
    session = session_manager.get_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    # Return user info for access control
    return {
        "user_id": session["user_info"].get("preferred_username"),
        "username": session["user_info"].get("preferred_username"),
        "email": session["user_info"].get("email"),
        "name": session["user_info"].get("name"),
        "authenticated": True
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

# Proxy endpoints for Reports API (BFF pattern)
@app.get("/api/reports/data-availability")
async def proxy_data_availability(session: dict = Depends(get_current_session)):
    """Proxy data availability request to Reports API"""
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated. Session cookie required.")
    
    try:
        # Call Reports API with session cookie
        response = keycloak_auth.client.get(
            "http://bionicpro-reports:8002/api/reports/data-availability",
            headers={"X-User-ID": session["user_info"]["preferred_username"]}
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Error proxying to Reports API: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch data availability")

@app.get("/api/reports/my-report")
async def proxy_my_report(
    session: dict = Depends(get_current_session),
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Proxy user report request to Reports API"""
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated. Session cookie required.")
    
    try:
        # Build query params
        params = {}
        if start_date:
            params["start_date"] = start_date
        if end_date:
            params["end_date"] = end_date
        
        # Call Reports API with user_id header
        response = keycloak_auth.client.get(
            "http://bionicpro-reports:8002/api/reports/my-report",
            headers={"X-User-ID": session["user_info"]["preferred_username"]},
            params=params
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Error proxying to Reports API: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch report: {str(e)}")

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
