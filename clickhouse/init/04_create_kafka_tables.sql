-- ClickHouse KafkaEngine Tables for CDC (Assignment 4)
-- Consumes data from Kafka topics populated by Debezium

-- =======================
-- KAFKA SOURCE TABLES
-- =======================

-- Kafka table for customers (consumes from Debezium CDC topic)
CREATE TABLE IF NOT EXISTS bionicpro.customers_kafka (
    customer_id Int32,
    username String,
    full_name String,
    email String,
    phone String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = Kafka()
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'bionicpro.crm.public.customers',
    kafka_group_name = 'clickhouse_customers_consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

-- Kafka table for prostheses
CREATE TABLE IF NOT EXISTS bionicpro.prostheses_kafka (
    prosthesis_id String,
    customer_id Int32,
    model String,
    manufacture_date Date,
    status String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = Kafka()
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'bionicpro.crm.public.prostheses',
    kafka_group_name = 'clickhouse_prostheses_consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

-- Kafka table for orders
CREATE TABLE IF NOT EXISTS bionicpro.orders_kafka (
    order_id Int32,
    customer_id Int32,
    prosthesis_id String,
    order_date DateTime,
    amount Float64,
    status String,
    created_at DateTime,
    updated_at DateTime
) ENGINE = Kafka()
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'bionicpro.crm.public.orders',
    kafka_group_name = 'clickhouse_orders_consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 10;

-- =======================
-- TARGET STORAGE TABLES (MergeTree)
-- =======================

-- Target table for customers (persistent storage)
CREATE TABLE IF NOT EXISTS bionicpro.customers (
    customer_id Int32,
    username String,
    full_name String,
    email String,
    phone String,
    created_at DateTime,
    updated_at DateTime,
    _ingested_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(_ingested_at)
PARTITION BY toYYYYMM(created_at)
ORDER BY (customer_id, username);

-- Target table for prostheses
CREATE TABLE IF NOT EXISTS bionicpro.prostheses (
    prosthesis_id String,
    customer_id Int32,
    model String,
    manufacture_date Date,
    status String,
    created_at DateTime,
    updated_at DateTime,
    _ingested_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(_ingested_at)
PARTITION BY toYYYYMM(manufacture_date)
ORDER BY (prosthesis_id, customer_id);

-- Target table for orders
CREATE TABLE IF NOT EXISTS bionicpro.orders (
    order_id Int32,
    customer_id Int32,
    prosthesis_id String,
    order_date DateTime,
    amount Float64,
    status String,
    created_at DateTime,
    updated_at DateTime,
    _ingested_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(_ingested_at)
PARTITION BY toYYYYMM(order_date)
ORDER BY (order_id, customer_id);

