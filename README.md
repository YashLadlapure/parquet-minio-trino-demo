# parquet-minio-trino-demo

Query 2-3 Parquet files stored in MinIO using Trino. Hive Metastore holds the table metadata, Postgres backs the metastore, and Trino runs the SQL. Everything runs as Docker containers.

---

## Stack

| Container | Image | Port | Role |
|---|---|---|---|
| minio | minio/minio:latest | 9000, 9001 | S3-compatible object store — holds Parquet files |
| postgres | postgres:14 | — | Backend DB for Hive Metastore (DB name: `metastore`) |
| hive-metastore | naushadh/hive-metastore:latest | 9083 | Standalone Hive Metastore (thrift) backed by Postgres |
| trino | trinodb/trino:435 | 8080 | Distributed SQL engine — reads Parquet via Hive |

> Note: HiveServer2 is not needed. Trino connects directly to the Hive Metastore thrift service on port 9083. Tables are registered directly via Trino SQL.

---

## Project layout

```
parquet-minio-trino-demo/
├── docker-compose.yml
├── trino/
│   └── catalog/
│       └── hive.properties          # Trino Hive catalog config
├── hive/
│   └── create_tables.sql          # DDL to run inside Trino CLI
├── data/
│   ├── generate_parquet.py        # Step 1: generates sample Parquet files
│   ├── upload_to_minio.py         # Step 3: uploads files into MinIO
│   └── output/                    # generated Parquet files (gitignored)
├── queries/
│   └── demo_queries.sql           # SQL to run in Trino
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

## Step 2 — Start all containers

```bash
docker compose up -d
```

Wait for all containers to be healthy:

```bash
docker compose ps
```

Expected: minio, postgres, hive-metastore, trino all `running`.

> hive-metastore initializes the Postgres schema on first start. Takes ~30 seconds.

---

## Step 3 — Upload Parquet files to MinIO

```bash
cd data
pip install minio
python upload_to_minio.py
cd ..
```

Verify in MinIO console: [http://localhost:9001](http://localhost:9001) — login `minioadmin / minioadmin`

---

## Step 4 — Register Hive tables via Trino

No beeline needed. Connect to Trino and run the DDL directly:

```bash
docker exec -it trino trino
```

Then paste the contents of `hive/create_tables.sql`:

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

Or run directly without entering the shell:

**Windows (PowerShell):**
```powershell
Get-Content hive\create_tables.sql | docker exec -i trino trino
```

**Mac/Linux:**
```bash
docker exec -i trino trino < hive/create_tables.sql
```

---

## Step 5 — Query with Trino

Open Trino UI: [http://localhost:8080](http://localhost:8080)

Connect via CLI:

```bash
docker exec -it trino trino
```

Quick checks:

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

Three-way join:

```sql
SELECT c.name AS customer, p.name AS product, p.category, s.amount
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

## Troubleshooting

**hive-metastore crashes on startup**  
Make sure you ran `docker compose down -v` to clear old Postgres volumes before restarting.

**Trino can't reach MinIO**  
Check `hive.s3.endpoint` in `trino/catalog/hive.properties`. It must be `http://minio:9000`.

**Hive table LOCATION mismatch**  
The `s3a://demo-bucket/data/sales` path in `create_tables.sql` must match the object path from the upload script.

**Port 8080 already in use**  
Change `8080:8080` to `8888:8080` in `docker-compose.yml`.

---

## Reference

- [Trino Hive connector docs](https://trino.io/docs/current/connector/hive.html)
- [naushadh/hive-metastore Docker image](https://hub.docker.com/r/naushadh/hive-metastore)
- [MinIO Python SDK](https://min.io/docs/minio/linux/developers/python/minio-py.html)
- [trinodb/trino Docker image](https://hub.docker.com/r/trinodb/trino)
