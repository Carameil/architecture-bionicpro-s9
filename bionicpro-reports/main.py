"""
BionicPRO Reports Service

REST API for retrieving user prosthesis reports from ClickHouse OLAP database.
Implements access control - users can only access their own reports.
"""

from fastapi import FastAPI, Depends, HTTPException, status, Query
from fastapi.middleware.cors import CORSMiddleware
from datetime import date, timedelta
from typing import Optional, List
import logging

from config import settings
from auth import get_current_user, User
from clickhouse_client import get_clickhouse_client, ClickHouseClient

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI application
app = FastAPI(
    title="BionicPRO Reports Service",
    description="API for retrieving prosthesis usage reports",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "bionicpro-reports",
        "version": "1.0.0"
    }


@app.get("/api/reports/my-report")
async def get_my_report(
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    current_user: User = Depends(get_current_user),
    ch_client: ClickHouseClient = Depends(get_clickhouse_client)
):
    """
    Get authenticated user's prosthesis reports
    
    This endpoint:
    1. Validates user session via BFF
    2. Retrieves ONLY the authenticated user's data (access control)
    3. Returns reports from ClickHouse OLAP database
    4. Ensures data is only from processed ETL periods
    
    Args:
        start_date: Optional filter - start date
        end_date: Optional filter - end date
        current_user: Injected by authentication dependency
        ch_client: ClickHouse client dependency
        
    Returns:
        JSON with user reports and metadata
    """
    logger.info(f"Report request from user: {current_user.username}")
    
    # Get latest available data date from ClickHouse
    latest_data_date = ch_client.get_latest_data_date()
    
    if not latest_data_date:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No data available yet. ETL processing may be in progress."
        )
    
    # Validate date range
    if end_date and end_date > latest_data_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Data only available until {latest_data_date.isoformat()}. " 
                   f"Requested end date {end_date.isoformat()} is in the future or not yet processed."
        )
    
    if start_date and end_date and start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before or equal to end_date"
        )
    
    # Set default date range if not provided (last 30 days)
    if not start_date:
        start_date = latest_data_date - timedelta(days=30)
    
    if not end_date:
        end_date = latest_data_date
    
    # Query ClickHouse - CRITICAL: use user_id from authenticated session
    # This ensures users can ONLY see their own reports
    try:
        reports = ch_client.get_user_reports(
            user_id=current_user.user_id,  # ← Access control enforcement
            start_date=start_date,
            end_date=end_date
        )
    except Exception as e:
        logger.error(f"Error retrieving reports: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error retrieving reports from database"
        )
    
    # Return response
    return {
        "user_id": current_user.user_id,
        "username": current_user.username,
        "date_range": {
            "start": start_date.isoformat(),
            "end": end_date.isoformat()
        },
        "data_available_until": latest_data_date.isoformat(),
        "total_reports": len(reports),
        "reports": reports
    }


@app.get("/api/reports/data-availability")
async def get_data_availability(
    current_user: User = Depends(get_current_user),
    ch_client: ClickHouseClient = Depends(get_clickhouse_client)
):
    """
    Get information about data availability
    
    Returns the latest date for which data is available,
    useful for the frontend to know what date ranges are valid.
    """
    latest_date = ch_client.get_latest_data_date()
    
    if not latest_date:
        return {
            "data_available": False,
            "message": "No data available yet. ETL processing may be in progress."
        }
    
    return {
        "data_available": True,
        "latest_date": latest_date.isoformat(),
        "user_id": current_user.user_id
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
