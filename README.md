# parquet-minio-trino-demo

Query 2-3 Parquet files stored in MinIO using Trino. Hive Metastore holds the table metadata, Postgres backs the metastore, and Trino runs the SQL. Everything runs as Docker containers.

---

## Stack

| Container | Image | Role |
|---|---|---|
| minio | minio/minio:latest | S3-compatible object store — holds Parquet files |
| postgres | postgres:14 | Backend DB for Hive Metastore |
| hive-metastore | apache/hive:3.1.3 | Stores table schemas and MinIO paths |
| trino | trinodb/trino:435 | Distributed SQL engine — reads Parquet via Hive |

---

## Project layout

```
parquet-minio-trino-demo/
├── docker-compose.yml
├── trino/
│   └── catalog/
│       └── hive.properties          # Trino Hive catalog config
├── hive/
│   └── create_tables.sql          # DDL to register tables in Hive Metastore
├── data/
│   ├── generate_parquet.py        # Step 1: generates sales, customers, products Parquet files
│   ├── upload_to_minio.py         # Step 3: uploads Parquet files directly into MinIO bucket
│   └── output/                    # generated Parquet files (gitignored)
├── queries/
│   └── demo_queries.sql           # SQL to run in Trino
└── .gitignore
```

---

## Prerequisites

- Docker Desktop running (with Compose v2)
- Python 3.x

No `mc` or other external tools needed.

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

Wait for all four containers to be healthy:

```bash
docker compose ps
```

Expected: minio, postgres, hive-metastore, trino all `running`.

---

## Step 3 — Upload Parquet files to MinIO (Python)

No `mc.exe` needed. Run the uploader script directly:

```bash
cd data
pip install minio
python upload_to_minio.py
cd ..
```

This creates `demo-bucket` in MinIO and uploads all three Parquet files into:
- `data/sales/sales.parquet`
- `data/customers/customers.parquet`
- `data/products/products.parquet`

Verify in MinIO console: [http://localhost:9001](http://localhost:9001) — login `minioadmin / minioadmin`

---

## Step 4 — Register Hive tables

**Windows (PowerShell):**

```powershell
Get-Content hive\create_tables.sql | docker exec -i hive-metastore beeline -u jdbc:hive2://localhost:10000
```

**Mac/Linux:**

```bash
docker exec -i hive-metastore beeline -u jdbc:hive2://localhost:10000 < hive/create_tables.sql
```

Verify tables are registered:

```bash
docker exec -it hive-metastore beeline -u jdbc:hive2://localhost:10000 -e "SHOW TABLES IN demo;"
```

---

## Step 5 — Query with Trino

Open Trino UI: [http://localhost:8080](http://localhost:8080)

Connect via CLI:

```bash
docker exec -it trino trino --catalog hive --schema demo
```

Run the queries from `queries/demo_queries.sql`.

Quick check:

```sql
SELECT * FROM hive.demo.sales LIMIT 10;
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

The `-v` flag removes the named volumes so you start fresh next time.

---

## Troubleshooting

**`upload_to_minio.py` connection refused**  
Make sure `docker compose up -d` is running and MinIO is healthy before running the upload script.

**Trino can't reach MinIO**  
Check `hive.s3.endpoint` in `trino/catalog/hive.properties`. It must be `http://minio:9000` (container name, not localhost).

**Hive table LOCATION mismatch**  
The `s3a://demo-bucket/data/sales/` path in `create_tables.sql` must match the object path used in the upload script.

**Hive Metastore keeps restarting**  
Run `docker compose restart hive-metastore` after Postgres is fully up.

**Port 8080 already in use**  
Change `8080:8080` to `8888:8080` in `docker-compose.yml`.

---

## Reference

- [Deploy MinIO and Trino with Kubernetes](https://www.min.io/blog/minio-trino-kubernetes) — original reference
- [Trino Hive connector docs](https://trino.io/docs/current/connector/hive.html)
- [MinIO Python SDK](https://min.io/docs/minio/linux/developers/python/minio-py.html)
- [trinodb/trino Docker image](https://hub.docker.com/r/trinodb/trino)
