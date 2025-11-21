"""S3 client for caching reports in MinIO"""

import boto3
from botocore.client import Config as BotoConfig
from botocore.exceptions import ClientError
import json
import logging
from typing import Optional
from datetime import datetime, timedelta
from config import settings

logger = logging.getLogger(__name__)


class S3ReportCache:
    """S3-based cache for user reports"""
    
    def __init__(self):
        # Initialize S3 client for MinIO
        self.s3_client = boto3.client(
            's3',
            endpoint_url=settings.S3_ENDPOINT_URL,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY,
            config=BotoConfig(signature_version='s3v4'),
            region_name='us-east-1'
        )
        
        self.bucket_name = settings.S3_BUCKET_NAME
        self._ensure_bucket_exists()
        
        logger.info(f"S3 client initialized for bucket: {self.bucket_name}")
    
    def _ensure_bucket_exists(self):
        """Create bucket if it doesn't exist"""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            logger.info(f"Bucket {self.bucket_name} exists")
        except ClientError:
            # Bucket doesn't exist, create it
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
                logger.info(f"Created bucket: {self.bucket_name}")
            except Exception as e:
                logger.error(f"Error creating bucket: {e}")
    
    def _get_report_key(self, user_id: str, start_date: str, end_date: str) -> str:
        """
        Generate S3 key for report
        
        Structure: reports/{user_id}/{year}/{month}/report_{start}_{end}.json
        This structure allows fast access and easy cleanup
        """
        year = start_date[:4]
        month = start_date[5:7]
        return f"reports/{user_id}/{year}/{month}/report_{start_date}_{end_date}.json"
    
    def get_cached_report(self, user_id: str, start_date: str, end_date: str) -> Optional[dict]:
        """
        Get cached report from S3
        
        Returns:
            Report data if exists, None otherwise
        """
        key = self._get_report_key(user_id, start_date, end_date)
        
        try:
            response = self.s3_client.get_object(Bucket=self.bucket_name, Key=key)
            data = json.loads(response['Body'].read())
            logger.info(f"Cache HIT for {user_id}: {key}")
            return data
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                logger.info(f"Cache MISS for {user_id}: {key}")
                return None
            else:
                logger.error(f"Error retrieving from S3: {e}")
                return None
    
    def save_report(self, user_id: str, start_date: str, end_date: str, report_data: dict) -> str:
        """
        Save report to S3
        
        Returns:
            S3 key of saved report
        """
        key = self._get_report_key(user_id, start_date, end_date)
        
        try:
            # Add metadata
            report_with_meta = {
                **report_data,
                "cached_at": datetime.utcnow().isoformat(),
                "cache_key": key
            }
            
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=key,
                Body=json.dumps(report_with_meta),
                ContentType='application/json',
                Metadata={
                    'user_id': user_id,
                    'start_date': start_date,
                    'end_date': end_date,
                    'cached_at': datetime.utcnow().isoformat()
                }
            )
            
            logger.info(f"Saved report to S3: {key}")
            return key
            
        except Exception as e:
            logger.error(f"Error saving to S3: {e}")
            raise
    
    def get_cdn_url(self, s3_key: str) -> str:
        """
        Generate CDN URL for accessing report through Nginx
        
        Args:
            s3_key: S3 object key
            
        Returns:
            CDN URL
        """
        # Remove 'reports/' prefix from key for CDN URL
        cdn_path = s3_key.replace('reports/', '')
        return f"{settings.CDN_BASE_URL}/reports/{cdn_path}"
    
    def invalidate_user_reports(self, user_id: str, date_prefix: Optional[str] = None):
        """
        Delete all cached reports for a user (cache invalidation)
        
        Args:
            user_id: User identifier
            date_prefix: Optional date prefix (YYYY-MM) to delete only specific month
        """
        try:
            prefix = f"reports/{user_id}/"
            if date_prefix:
                prefix += f"{date_prefix}/"
            
            # List and delete objects
            response = self.s3_client.list_objects_v2(Bucket=self.bucket_name, Prefix=prefix)
            
            if 'Contents' in response:
                objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]
                if objects_to_delete:
                    self.s3_client.delete_objects(
                        Bucket=self.bucket_name,
                        Delete={'Objects': objects_to_delete}
                    )
                    logger.info(f"Invalidated {len(objects_to_delete)} cached reports for {user_id}")
            else:
                logger.info(f"No cached reports found for {user_id}")
                
        except Exception as e:
            logger.error(f"Error invalidating cache: {e}")


# Singleton instance
_s3_cache: Optional[S3ReportCache] = None


def get_s3_cache() -> S3ReportCache:
    """Get or create S3 cache instance"""
    global _s3_cache
    if _s3_cache is None:
        _s3_cache = S3ReportCache()
    return _s3_cache
