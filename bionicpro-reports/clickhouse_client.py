"""ClickHouse client for BionicPRO Reports"""

from typing import List, Dict, Any, Optional
from datetime import date, datetime
from clickhouse_driver import Client
from config import settings
import logging

logger = logging.getLogger(__name__)


class ClickHouseClient:
    """Client for interacting with ClickHouse OLAP database"""
    
    def __init__(self):
        self.client = Client(
            host=settings.CLICKHOUSE_HOST,
            port=settings.CLICKHOUSE_PORT,
            database=settings.CLICKHOUSE_DATABASE,
            user=settings.CLICKHOUSE_USER,
            password=settings.CLICKHOUSE_PASSWORD
        )
        logger.info(f"Connected to ClickHouse at {settings.CLICKHOUSE_HOST}:{settings.CLICKHOUSE_PORT}")
    
    def get_user_reports(
        self,
        user_id: str,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> List[Dict[str, Any]]:
        """
        Get reports for a specific user
        
        Args:
            user_id: User identifier (MUST come from authenticated session)
            start_date: Optional start date filter
            end_date: Optional end date filter
            
        Returns:
            List of report dictionaries
        """
        query = """
            SELECT 
                user_id,
                report_date,
                prosthesis_id,
                total_movements,
                avg_response_time_ms,
                max_response_time_ms,
                min_response_time_ms,
                battery_avg_percent,
                battery_min_percent,
                error_count,
                total_usage_hours,
                customer_name,
                customer_email,
                prosthesis_model,
                prosthesis_manufacture_date,
                etl_updated_at
            FROM user_reports_latest
            WHERE user_id = %(user_id)s
        """
        
        params = {"user_id": user_id}
        
        # Add date filters if provided
        if start_date:
            query += " AND report_date >= %(start_date)s"
            params["start_date"] = start_date
        
        if end_date:
            query += " AND report_date <= %(end_date)s"
            params["end_date"] = end_date
        
        query += " ORDER BY report_date DESC LIMIT 100"
        
        logger.info(f"Querying reports for user: {user_id}")
        
        try:
            result = self.client.execute(query, params, with_column_types=True)
            
            # result[0] contains data, result[1] contains column info
            rows = result[0]
            columns = [col[0] for col in result[1]]
            
            # Convert to list of dictionaries
            reports = []
            for row in rows:
                report = dict(zip(columns, row))
                # Convert datetime objects to ISO strings for JSON serialization
                for key, value in report.items():
                    if isinstance(value, (date, datetime)):
                        report[key] = value.isoformat()
                reports.append(report)
            
            logger.info(f"Found {len(reports)} reports for user {user_id}")
            return reports
            
        except Exception as e:
            logger.error(f"Error querying ClickHouse: {e}")
            raise
    
    def get_latest_data_date(self) -> Optional[date]:
        """
        Get the latest date for which data is available
        
        Returns:
            Latest report_date or None if no data
        """
        query = "SELECT max(report_date) as latest_date FROM user_reports"
        
        try:
            result = self.client.execute(query)
            if result and result[0] and result[0][0]:
                return result[0][0]
            return None
        except Exception as e:
            logger.error(f"Error getting latest data date: {e}")
            return None
    
    def check_data_available_for_date(self, check_date: date) -> bool:
        """
        Check if data is available for a specific date
        
        Args:
            check_date: Date to check
            
        Returns:
            True if data exists for that date
        """
        query = "SELECT count() FROM user_reports WHERE report_date = %(date)s"
        
        try:
            result = self.client.execute(query, {"date": check_date})
            return result[0][0] > 0
        except Exception as e:
            logger.error(f"Error checking data availability: {e}")
            return False
    
    def close(self):
        """Close ClickHouse connection"""
        self.client.disconnect()
        logger.info("Disconnected from ClickHouse")


# Singleton instance
_clickhouse_client: Optional[ClickHouseClient] = None


def get_clickhouse_client() -> ClickHouseClient:
    """Get or create ClickHouse client instance"""
    global _clickhouse_client
    if _clickhouse_client is None:
        _clickhouse_client = ClickHouseClient()
    return _clickhouse_client
