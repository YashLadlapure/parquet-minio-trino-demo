-- Run inside Trino CLI:
--   docker exec -it trino trino
-- OR on Windows PowerShell:
--   Get-Content hive\create_tables.sql | docker exec -i trino trino

CREATE SCHEMA IF NOT EXISTS hive.demo
WITH (location = 's3a://demo-bucket/data/');

CREATE TABLE IF NOT EXISTS hive.demo.sales (
  order_id    BIGINT,
  customer_id BIGINT,
  product_id  BIGINT,
  amount      DOUBLE
)
WITH (
  external_location = 's3a://demo-bucket/data/sales',
  format = 'PARQUET'
);

CREATE TABLE IF NOT EXISTS hive.demo.customers (
  customer_id BIGINT,
  name        VARCHAR,
  city        VARCHAR
)
WITH (
  external_location = 's3a://demo-bucket/data/customers',
  format = 'PARQUET'
);

CREATE TABLE IF NOT EXISTS hive.demo.products (
  product_id BIGINT,
  name       VARCHAR,
  category   VARCHAR
)
WITH (
  external_location = 's3a://demo-bucket/data/products',
  format = 'PARQUET'
);
