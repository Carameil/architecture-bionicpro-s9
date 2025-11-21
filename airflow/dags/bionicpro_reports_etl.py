"""
BionicPRO Reports ETL DAG

This DAG extracts data from CRM DB (Oracle) and Telemetry DB (PostgreSQL),
transforms and joins them, then loads aggregated reports into ClickHouse.

Schedule: Daily at 02:00 AM
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.http.hooks.http import HttpHook
import pandas as pd
import logging

logger = logging.getLogger(__name__)

# Default arguments
default_args = {
    'owner': 'bionicpro',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'start_date': datetime(2025, 11, 1),
}

# DAG definition
dag = DAG(
    'bionicpro_reports_etl',
    default_args=default_args,
    description='ETL pipeline for BionicPRO user reports',
    schedule_interval='0 2 * * *',  # Daily at 02:00
    catchup=False,
    tags=['bionicpro', 'etl', 'reports'],
)


def extract_crm_data(**context):
    """
    Extract customer data from CRM Database (Oracle)
    
    Returns: DataFrame with customer information
    """
    logger.info("Extracting CRM data...")
    
    # For demo purposes, using mock data
    # In production, use: OracleHook or PostgresHook
    
    # Mock CRM data
    crm_data = {
        'user_id': ['john.doe', 'jane.smith', 'alex.johnson'],
        'customer_name': ['John Doe', 'Jane Smith', 'Alex Johnson'],
        'customer_email': ['john@example.com', 'jane@example.com', 'alex@example.com'],
        'prosthesis_id': ['BP-12345', 'BP-23456', 'BP-34567'],
        'prosthesis_model': ['BionicArm Pro X1', 'BionicHand Elite', 'BionicArm Pro X2'],
        'prosthesis_manufacture_date': ['2024-06-15', '2024-07-20', '2024-08-10']
    }
    
    df_crm = pd.DataFrame(crm_data)
    logger.info(f"Extracted {len(df_crm)} CRM records")
    
    # Push to XCom for next task
    context['task_instance'].xcom_push(key='crm_data', value=df_crm.to_dict('records'))
    
    return f"Extracted {len(df_crm)} CRM records"


def extract_telemetry_data(**context):
    """
    Extract telemetry data from Telemetry Database (PostgreSQL)
    
    Returns: DataFrame with aggregated telemetry metrics
    """
    logger.info("Extracting telemetry data...")
    
    # For demo purposes, using mock data
    # In production, use PostgresHook to connect to Telemetry DB
    
    # Mock telemetry data (aggregated by user and date)
    telemetry_data = {
        'user_id': ['john.doe', 'jane.smith', 'alex.johnson'],
        'prosthesis_id': ['BP-12345', 'BP-23456', 'BP-34567'],
        'report_date': [datetime.now().date()] * 3,
        'total_movements': [15234, 13567, 17894],
        'avg_response_time_ms': [87.3, 92.4, 83.2],
        'max_response_time_ms': [145.2, 165.7, 138.9],
        'min_response_time_ms': [52.1, 55.2, 49.7],
        'battery_avg_percent': [85.2, 79.3, 91.2],
        'battery_min_percent': [72.0, 65.0, 80.0],
        'error_count': [3, 4, 1],
        'total_usage_hours': [12.5, 10.3, 14.7]
    }
    
    df_telemetry = pd.DataFrame(telemetry_data)
    logger.info(f"Extracted {len(df_telemetry)} telemetry records")
    
    # Push to XCom
    context['task_instance'].xcom_push(key='telemetry_data', value=df_telemetry.to_dict('records'))
    
    return f"Extracted {len(df_telemetry)} telemetry records"


def transform_and_join(**context):
    """
    Join CRM and Telemetry data, perform transformations
    
    Returns: DataFrame with merged and transformed data
    """
    logger.info("Transforming and joining data...")
    
    # Pull data from XCom
    ti = context['task_instance']
    crm_records = ti.xcom_pull(task_ids='extract_crm_data', key='crm_data')
    telemetry_records = ti.xcom_pull(task_ids='extract_telemetry_data', key='telemetry_data')
    
    if not crm_records or not telemetry_records:
        raise ValueError("No data received from extraction tasks")
    
    # Convert to DataFrames
    df_crm = pd.DataFrame(crm_records)
    df_telemetry = pd.DataFrame(telemetry_records)
    
    # Join on user_id and prosthesis_id
    df_merged = pd.merge(
        df_telemetry,
        df_crm,
        on=['user_id', 'prosthesis_id'],
        how='inner'
    )
    
    # Add ETL metadata
    df_merged['etl_updated_at'] = datetime.now()
    df_merged['data_version'] = 1
    
    logger.info(f"Merged {len(df_merged)} records")
    
    # Push to XCom
    ti.xcom_push(key='merged_data', value=df_merged.to_dict('records'))
    
    return f"Transformed {len(df_merged)} records"


def load_to_clickhouse(**context):
    """
    Load transformed data into ClickHouse OLAP database
    """
    logger.info("Loading data to ClickHouse...")
    
    # Pull data from XCom
    ti = context['task_instance']
    merged_records = ti.xcom_pull(task_ids='transform_and_join', key='merged_data')
    
    if not merged_records:
        raise ValueError("No data to load")
    
    df = pd.DataFrame(merged_records)
    
    # In production, use ClickHouseHook or HTTP API
    # For now, log the data
    logger.info(f"Would insert {len(df)} records into ClickHouse")
    logger.info(f"Sample data:\n{df.head()}")
    
    # Mock insert
    # In production:
    # from clickhouse_driver import Client
    # client = Client(host='clickhouse', port=9000)
    # client.execute('INSERT INTO bionicpro.user_reports VALUES', df.to_dict('records'))
    
    return f"Loaded {len(df)} records to ClickHouse"


# Define tasks
task_extract_crm = PythonOperator(
    task_id='extract_crm_data',
    python_callable=extract_crm_data,
    dag=dag,
)

task_extract_telemetry = PythonOperator(
    task_id='extract_telemetry_data',
    python_callable=extract_telemetry_data,
    dag=dag,
)

task_transform = PythonOperator(
    task_id='transform_and_join',
    python_callable=transform_and_join,
    dag=dag,
)

task_load = PythonOperator(
    task_id='load_to_clickhouse',
    python_callable=load_to_clickhouse,
    dag=dag,
)

# Define dependencies
[task_extract_crm, task_extract_telemetry] >> task_transform >> task_load
