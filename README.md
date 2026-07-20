# parquet-minio-trino-demo

Query multiple Parquet files stored in MinIO using Trino.

No Hive Metastore. No Postgres. Just two containers.

---

## Stack

| Container | Image | Port |
|---|---|---|
| minio | `minio/minio:latest` | 9000, 9001 |
| trino | `trinodb/trino:435` | 8080 |

---

## How it works

```
generate_parquet.py
        │
        ▼
  data/output/*.parquet
        │
        ▼ upload_to_minio.py
        │
        ▼
  MinIO  s3a://demo-bucket/data/sales/
         s3a://demo-bucket/data/customers/
         s3a://demo-bucket/data/products/
        │
        ▼ CREATE TABLE ... WITH (external_location, format='PARQUET')
        │
        ▼
  Trino  SELECT / JOIN across 3 Parquet-backed tables
```

Trino uses the Hive connector with `hive.metastore=file`. Table metadata is registered at runtime via DDL — no running Hive service needed.

---

## Project layout

```
parquet-minio-trino-demo/
├── docker-compose.yml          # minio + trino
├── trino/catalog/hive.properties
├── data/
│   ├── generate_parquet.py      # Step 1
│   └── upload_to_minio.py       # Step 3
├── hive/create_tables.sql       # Step 4  (Trino DDL)
├── queries/demo_queries.sql     # Step 5  (demo SQL)
└── README.md
```

---

## Prerequisites

- Docker Desktop
- Python 3.x

---

## Step 1 — Generate Parquet files

```bash
cd data
pip install pandas pyarrow
python generate_parquet.py
cd ..
```

Creates three files in `data/output/`:
- `sales.parquet` — order_id, customer_id, product_id, amount
- `customers.parquet` — customer_id, name, city
- `products.parquet` — product_id, name, category

---

## Step 2 — Start containers

```bash
docker compose up -d
docker compose ps
```

Expected: `minio` and `trino` both running.

---

## Step 3 — Upload to MinIO

```bash
cd data
pip install minio
python upload_to_minio.py
cd ..
```

Verify at [http://localhost:9001](http://localhost:9001) — login `minioadmin / minioadmin`.

You should see `demo-bucket/data/sales/`, `customers/`, `products/`.

---

## Step 4 — Register tables in Trino

```bash
docker exec -it trino trino
```

Paste `hive/create_tables.sql` or run:

```sql
CREATE SCHEMA IF NOT EXISTS hive.demo
WITH (location = 's3a://demo-bucket/data/');

CREATE TABLE IF NOT EXISTS hive.demo.sales (
  order_id    BIGINT,
  customer_id BIGINT,
  product_id  BIGINT,
  amount      DOUBLE
) WITH (external_location = 's3a://demo-bucket/data/sales', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS hive.demo.customers (
  customer_id BIGINT,
  name        VARCHAR,
  city        VARCHAR
) WITH (external_location = 's3a://demo-bucket/data/customers', format = 'PARQUET');

CREATE TABLE IF NOT EXISTS hive.demo.products (
  product_id BIGINT,
  name       VARCHAR,
  category   VARCHAR
) WITH (external_location = 's3a://demo-bucket/data/products', format = 'PARQUET');
```

On Windows PowerShell:

```powershell
Get-Content hive\create_tables.sql | docker exec -i trino trino
```

---

## Step 5 — Run queries

Trino UI: [http://localhost:8080](http://localhost:8080)

```sql
-- basic row check
SELECT * FROM hive.demo.sales LIMIT 10;

-- join two Parquet files
SELECT c.name, c.city, s.amount
FROM hive.demo.sales s
JOIN hive.demo.customers c ON s.customer_id = c.customer_id
WHERE s.amount > 1000;

-- three-way join across all three Parquet files
SELECT c.name AS customer, p.name AS product, p.category, s.amount
FROM hive.demo.sales s
JOIN hive.demo.customers c ON s.customer_id = c.customer_id
JOIN hive.demo.products  p ON s.product_id  = p.product_id
ORDER BY s.amount DESC;
```

See `queries/demo_queries.sql` for more (aggregations, GROUP BY, category totals).

---

## Tear down

```bash
docker compose down -v
```

---

## Troubleshooting

**Upload fails (connection refused)** — wait for MinIO to be healthy before running `upload_to_minio.py`.

**CREATE TABLE fails in Trino** — check `trino/catalog/hive.properties`: `hive.s3.endpoint` must be `http://minio:9000`.

**Port 8080 in use** — change `8080:8080` to `8888:8080` in `docker-compose.yml`.
