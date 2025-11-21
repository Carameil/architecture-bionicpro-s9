"""Session management for BionicPRO Auth Service"""
import secrets
import time
from typing import Dict, Optional, Any
from datetime import datetime, timedelta
import json

class SessionManager:
    """In-memory session manager with rotation support"""
    
    def __init__(self, session_lifetime_minutes: int = 60):
        self.sessions: Dict[str, Dict[str, Any]] = {}
        self.session_lifetime = timedelta(minutes=session_lifetime_minutes)
        self.grace_period = timedelta(seconds=30)  # 30 seconds grace period for rotated sessions
        
    def create_session(
        self, 
        user_info: Dict[str, Any],
        access_token: str,
        refresh_token: str,
        expires_in: int,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None
    ) -> str:
        """Create new session and return session ID"""
        session_id = secrets.token_urlsafe(32)
        
        self.sessions[session_id] = {
            "user_info": user_info,
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_expires_at": time.time() + expires_in,
            "created_at": datetime.utcnow().isoformat(),
            "last_accessed": datetime.utcnow().isoformat(),
            "user_agent": user_agent,
            "ip_address": ip_address,
            "rotation_count": 0
        }
        
        return session_id
    
    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session by ID"""
        session = self.sessions.get(session_id)
        
        if not session:
            return None
            
        # Check if session is rotated and within grace period
        if session.get("is_rotated"):
            rotated_at = datetime.fromisoformat(session["rotated_at"])
            if datetime.utcnow() - rotated_at > self.grace_period:
                self.delete_session(session_id)
                return None
            # Return rotated session but don't update last_accessed
            return session

        # Check if session expired
        created_at = datetime.fromisoformat(session["created_at"])
        if datetime.utcnow() - created_at > self.session_lifetime:
            self.delete_session(session_id)
            return None
            
        # Update last accessed time
        session["last_accessed"] = datetime.utcnow().isoformat()
        
        return session
    
    def update_tokens(
        self, 
        session_id: str, 
        access_token: str, 
        refresh_token: Optional[str] = None,
        expires_in: int = 120
    ) -> bool:
        """Update session tokens"""
        session = self.sessions.get(session_id)
        if not session:
            return False
            
        session["access_token"] = access_token
        if refresh_token:
            session["refresh_token"] = refresh_token
        session["token_expires_at"] = time.time() + expires_in
        session["last_accessed"] = datetime.utcnow().isoformat()
        
        return True
    
    def rotate_session(
        self, 
        old_session_id: str,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None
    ) -> Optional[str]:
        """Rotate session - create new session ID while preserving data"""
        old_session = self.get_session(old_session_id)
        if not old_session or old_session.get("is_rotated"):
            return None
            
        # Verify request comes from same client
        if user_agent and old_session.get("user_agent") != user_agent:
            return None
            
        # Create new session with same data
        new_session_id = secrets.token_urlsafe(32)
        self.sessions[new_session_id] = {
            **old_session,
            "rotation_count": old_session.get("rotation_count", 0) + 1,
            "rotated_at": None,
            "is_rotated": False,
            "previous_session_id": old_session_id,
            "created_at": datetime.utcnow().isoformat(), # Reset creation time for new session? Usually yes, or keep original? Let's keep original to enforce max absolute lifetime if needed, but here we restart timer.
            "last_accessed": datetime.utcnow().isoformat()
        }
        
        # Mark old session as rotated instead of deleting
        self.sessions[old_session_id]["is_rotated"] = True
        self.sessions[old_session_id]["rotated_at"] = datetime.utcnow().isoformat()
        self.sessions[old_session_id]["next_session_id"] = new_session_id
        
        return new_session_id
    
    def delete_session(self, session_id: str) -> bool:
        """Delete session"""
        if session_id in self.sessions:
            del self.sessions[session_id]
            return True
        return False
    
    def is_token_expired(self, session_id: str) -> bool:
        """Check if access token is expired"""
        session = self.sessions.get(session_id)
        if not session:
            return True
            
        return time.time() > session.get("token_expires_at", 0)
    
    def cleanup_expired_sessions(self):
        """Remove expired sessions"""
        current_time = datetime.utcnow()
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            # Check rotated sessions
            if session.get("is_rotated"):
                rotated_at = datetime.fromisoformat(session["rotated_at"])
                if current_time - rotated_at > self.grace_period:
                    expired_sessions.append(session_id)
                continue

            # Check normal expired sessions
            created_at = datetime.fromisoformat(session["created_at"])
            if current_time - created_at > self.session_lifetime:
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            self.delete_session(session_id)
    
    def get_active_sessions_count(self) -> int:
        """Get count of active sessions"""
        self.cleanup_expired_sessions()
        return len(self.sessions)
    
    def get_user_sessions(self, user_id: str) -> list:
        """Get all sessions for a specific user"""
        user_sessions = []
        
        for session_id, session in self.sessions.items():
            if session.get("user_info", {}).get("sub") == user_id:
                user_sessions.append({
                    "session_id": session_id,
                    "created_at": session["created_at"],
                    "last_accessed": session["last_accessed"],
                    "user_agent": session.get("user_agent"),
                    "ip_address": session.get("ip_address"),
                    "rotation_count": session.get("rotation_count", 0)
                })
        
        return user_sessions

