CREATE DATABASE IF NOT EXISTS demo;

-- sales table pointing to the sales parquet files in MinIO
CREATE TABLE IF NOT EXISTS demo.sales (
  order_id    BIGINT,
  customer_id BIGINT,
  product_id  BIGINT,
  amount      DOUBLE
)
STORED AS PARQUET
LOCATION 's3a://demo-bucket/data/sales/';

-- customers table
CREATE TABLE IF NOT EXISTS demo.customers (
  customer_id BIGINT,
  name        STRING,
  city        STRING
)
STORED AS PARQUET
LOCATION 's3a://demo-bucket/data/customers/';

-- products table
CREATE TABLE IF NOT EXISTS demo.products (
  product_id BIGINT,
  name       STRING,
  category   STRING
)
STORED AS PARQUET
LOCATION 's3a://demo-bucket/data/products/';
