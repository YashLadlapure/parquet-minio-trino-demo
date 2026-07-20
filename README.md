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
│       └── hive.properties      # Trino Hive catalog config
├── hive/
│   └── create_tables.sql        # DDL to register tables in Hive Metastore
├── data/
│   ├── generate_parquet.py      # generates sales, customers, products Parquet files
│   └── output/                  # generated Parquet files (gitignored)
├── queries/
│   └── demo_queries.sql         # SQL to run in Trino
└── .gitignore
```

---

## Prerequisites

- Docker Desktop running (with Compose v2)
- Python 3.x
- `mc` (MinIO Client) — [install guide](https://min.io/docs/minio/linux/reference/minio-mc.html)

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

Wait for all four containers to be healthy. Check with:

```bash
docker compose ps
```

Expected: minio, postgres, hive-metastore, trino all running.

---

## Step 3 — Create MinIO bucket and upload Parquet files

```bash
# set up mc alias pointing at local MinIO
mc alias set local http://localhost:9000 minioadmin minioadmin

# create the bucket
mc mb local/demo-bucket

# upload each parquet file into its own directory
mc cp data/output/sales.parquet     local/demo-bucket/data/sales/
mc cp data/output/customers.parquet local/demo-bucket/data/customers/
mc cp data/output/products.parquet  local/demo-bucket/data/products/

# verify
mc ls local/demo-bucket/data/
```

The paths here must exactly match the LOCATION values in `hive/create_tables.sql`.

---

## Step 4 — Register Hive tables

Exec into the Hive Metastore container and open beeline:

```bash
docker exec -it hive-metastore beeline -u jdbc:hive2://localhost:10000
```

Paste and run the SQL from `hive/create_tables.sql`.

Or run it directly in one shot:

```bash
docker exec -i hive-metastore beeline -u jdbc:hive2://localhost:10000 < hive/create_tables.sql
```

---

## Step 5 — Query with Trino

Open the Trino UI in your browser: [http://localhost:8080](http://localhost:8080)

Or connect with the Trino CLI:

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

The `-v` flag removes the named volumes (MinIO data and Postgres data) so you start fresh next time.

---

## Troubleshooting

**Trino can't reach MinIO**  
Check `hive.s3.endpoint` in `trino/catalog/hive.properties`. It must be `http://minio:9000` (container name, not localhost).

**Hive table LOCATION mismatch**  
The `s3a://demo-bucket/data/sales/` path in `create_tables.sql` must match exactly what you used in `mc cp`.

**Hive Metastore keeps restarting**  
Make sure Postgres is fully up before Hive starts. The `depends_on + healthcheck` in the compose file handles this but if it fails run `docker compose restart hive-metastore`.

**Port 8080 already in use**  
Change the Trino port in `docker-compose.yml` from `8080:8080` to e.g. `8888:8080` and adjust accordingly.

---

## Reference

- [Deploy MinIO and Trino with Kubernetes](https://www.min.io/blog/minio-trino-kubernetes) — original reference
- [Trino Hive connector docs](https://trino.io/docs/current/connector/hive.html)
- [MinIO Client (mc) quickstart](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [trinodb/trino Docker image](https://hub.docker.com/r/trinodb/trino)
