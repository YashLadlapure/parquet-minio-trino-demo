# parquet-minio-trino-demo

Query multiple Parquet files stored in MinIO using Trino. No Hive Metastore required — Trino’s Hive connector registers external tables that point directly at Parquet files on MinIO.

---

## Stack

| Container | Image | Port | Role |
|---|---|---|---|
| minio | minio/minio:latest | 9000, 9001 | S3-compatible object store — holds Parquet files |
| trino | trinodb/trino:435 | 8080 | Distributed SQL engine — reads Parquet via Hive connector |

---

## Project layout

```
parquet-minio-trino-demo/
├── docker-compose.yml
├── trino/
│   └── catalog/
│       └── hive.properties          # Trino Hive catalog — points at MinIO
├── hive/
│   └── create_tables.sql          # Trino DDL to register external Parquet tables
├── data/
│   ├── generate_parquet.py        # Step 1: generate sample Parquet files
│   ├── upload_to_minio.py         # Step 3: upload Parquet files to MinIO bucket
│   └── output/                    # generated Parquet files (gitignored)
├── queries/
│   └── demo_queries.sql           # SQL joins to run in Trino
└── .gitignore
```

---

## Prerequisites

- Docker Desktop running (with Compose v2)
- Python 3.x

---

## Step 1 — Generate sample Parquet files

```bash
cd data
pip install pandas pyarrow
python generate_parquet.py
cd ..
```

This creates three files in `data/output/`:
- `sales.parquet` — order_id, customer_id, product_id, amount
- `customers.parquet` — customer_id, name, city
- `products.parquet` — product_id, name, category

---

## Step 2 — Start containers

```bash
docker compose up -d
docker compose ps
```

Expected: `minio` and `trino` both `running`.

---

## Step 3 — Upload Parquet files to MinIO

```bash
cd data
pip install minio
python upload_to_minio.py
cd ..
```

Verify in MinIO console: [http://localhost:9001](http://localhost:9001) — login `minioadmin / minioadmin`

You should see `demo-bucket` with three prefixes:
- `data/sales/`
- `data/customers/`
- `data/products/`

---

## Step 4 — Register Hive tables via Trino

Connect to Trino CLI:

```bash
docker exec -it trino trino
```

Paste (or pipe in) the contents of `hive/create_tables.sql`:

```sql
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
```

Or pipe directly on Windows:

```powershell
Get-Content hive\create_tables.sql | docker exec -i trino trino
```

---

## Step 5 — Query with Trino

Open Trino UI: [http://localhost:8080](http://localhost:8080)

Connect via CLI:

```bash
docker exec -it trino trino
```

Basic checks:

```sql
SELECT * FROM hive.demo.sales LIMIT 10;
SELECT * FROM hive.demo.customers LIMIT 10;
SELECT * FROM hive.demo.products LIMIT 10;
```

Join two Parquet-backed tables:

```sql
SELECT c.name, c.city, s.amount
FROM hive.demo.sales s
JOIN hive.demo.customers c ON s.customer_id = c.customer_id
WHERE s.amount > 1000;
```

Three-way join across all three Parquet files:

```sql
SELECT
  c.name     AS customer,
  p.name     AS product,
  p.category AS category,
  s.amount   AS amount
FROM hive.demo.sales s
JOIN hive.demo.customers c ON s.customer_id = c.customer_id
JOIN hive.demo.products  p ON s.product_id  = p.product_id
ORDER BY s.amount DESC;
```

---

## Tear down

```bash
docker compose down -v
```

---

## How it works

```
Parquet files
    │
    ▼
  MinIO (S3-compatible object store)
    │  s3a://demo-bucket/data/sales/
    │  s3a://demo-bucket/data/customers/
    │  s3a://demo-bucket/data/products/
    │
    ▼
  Trino (Hive connector)
    │  external tables point at MinIO paths
    │  reads Parquet files directly
    │
    ▼
  SQL joins across 3 Parquet-backed tables
```

Trino’s Hive connector stores external table metadata in memory (no running Hive process needed for this demo). It reads the Parquet column statistics and data directly from MinIO using the S3A protocol.

---

## Troubleshooting

**`upload_to_minio.py` connection refused**  
Make sure `docker compose up -d` is complete and MinIO is healthy before uploading.

**`CREATE SCHEMA` or `CREATE TABLE` fails in Trino**  
Check `trino/catalog/hive.properties` — `hive.s3.endpoint` must be `http://minio:9000` and `hive.metastore` must be set to `file` or not require a running thrift service.

**Port 8080 already in use**  
Change `8080:8080` to `8888:8080` in `docker-compose.yml`.

---

## Reference

- [Trino Hive connector docs](https://trino.io/docs/current/connector/hive.html)
- [MinIO Python SDK](https://min.io/docs/minio/linux/developers/python/minio-py.html)
- [trinodb/trino Docker image](https://hub.docker.com/r/trinodb/trino)
