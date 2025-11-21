"""Authentication and session validation for Reports Service"""

from typing import Optional
from fastapi import Header, HTTPException, status
import logging
from config import settings

logger = logging.getLogger(__name__)


class User:
    """Authenticated user model"""
    def __init__(self, user_id: str, username: str, email: Optional[str] = None):
        self.user_id = user_id
        self.username = username
        self.email = email


async def get_current_user(x_user_id: Optional[str] = Header(None)) -> User:
    """
    FastAPI dependency to get current authenticated user from BFF header
    
    The BFF (bionicpro-auth) validates the session and passes X-User-ID header.
    Reports API trusts this header as it comes from internal Docker network.
    
    Args:
        x_user_id: User ID header from BFF (injected by FastAPI)
        
    Returns:
        User object
        
    Raises:
        HTTPException: 401 if not authenticated
    """
    if not x_user_id:
        logger.warning("No X-User-ID header found in request")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated. Request must come through BFF."
        )
    
    logger.info(f"Authenticated user from BFF: {x_user_id}")
    
    return User(
        user_id=x_user_id,
        username=x_user_id,
        email=None  # Can be enriched if needed
    )
