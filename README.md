# parquet-minio-trino-demo

A hands-on demo showing how to query multiple Parquet files stored in MinIO using Trino. Hive Metastore holds the table metadata, Redis stores the schema definitions, and Trino runs the distributed SQL.

---

## What this does

You upload 2–3 Parquet files (sales, customers, products) to a MinIO bucket. Then you register them as Hive tables. Finally you run SQL through Trino — single selects, joins, and aggregations across all three files.

---

## Stack

| Component | Role |
|---|---|
| MinIO | S3-compatible object store, holds Parquet files |
| Hive Metastore + PostgreSQL | Stores table metadata (schemas, locations) |
| Redis | Stores Trino table schema JSON for Helm chart |
| Trino | Runs SQL queries over Parquet data |
| Kubernetes + Helm | Deploys everything locally |

---

## Prerequisites

- Docker Desktop (with Kubernetes enabled) or `kind`
- `kubectl` and `helm` installed
- `mc` (MinIO Client) installed
- Python 3.x (to generate sample Parquet files)

---

## Project layout

```
parquet-minio-trino-demo/
├── data/
│   └── generate_parquet.py       # script to create sample parquet files
├── hive/
│   └── create_tables.sql         # DDL to register tables in Hive
├── k8s/
│   ├── minio-values.yaml         # Helm values for MinIO
│   ├── hive-metastore.yaml       # Hive Metastore deployment manifest
│   ├── postgres.yaml             # PostgreSQL for Hive metadata
│   ├── redis.yaml                # Redis deployment
│   └── trino-values.yaml         # Helm values for Trino
├── queries/
│   └── demo_queries.sql          # SQL queries to run in Trino
└── README.md
```

---

## Setup steps

### 1. Generate sample Parquet files

```bash
cd data
pip install pandas pyarrow
python generate_parquet.py
```

This creates `sales.parquet`, `customers.parquet`, `products.parquet` in `data/output/`.

### 2. Deploy the stack

```bash
# MinIO
helm repo add minio https://charts.min.io
helm install minio minio/minio -f k8s/minio-values.yaml -n minio --create-namespace

# PostgreSQL (backend for Hive Metastore)
kubectl apply -f k8s/postgres.yaml -n hive

# Hive Metastore
kubectl apply -f k8s/hive-metastore.yaml -n hive

# Redis
kubectl apply -f k8s/redis.yaml -n trino

# Trino
helm repo add trino https://trinodb.github.io/charts
helm install trino trino/trino -f k8s/trino-values.yaml -n trino
```

### 3. Upload Parquet files to MinIO

```bash
# Port-forward MinIO
kubectl port-forward svc/minio 9000:9000 -n minio

# Set up mc alias
mc alias set local http://localhost:9000 minioadmin minioadmin

# Create bucket and upload
mc mb local/demo-bucket
mc cp data/output/sales.parquet      local/demo-bucket/data/sales/
mc cp data/output/customers.parquet  local/demo-bucket/data/customers/
mc cp data/output/products.parquet   local/demo-bucket/data/products/
```

### 4. Create Hive tables

Exec into the Hive Metastore pod and run:

```bash
kubectl exec -it deploy/hive-metastore -n hive -- beeline -u jdbc:hive2://localhost:10000
```

Then paste the contents of `hive/create_tables.sql`.

### 5. Query with Trino

```bash
# Port-forward Trino
kubectl port-forward svc/trino 8080:8080 -n trino

# Open Trino UI
open http://localhost:8080

# Or connect via CLI
trino --server localhost:8080 --catalog hive --schema demo
```

Run queries from `queries/demo_queries.sql`.

---

## Troubleshooting

**Trino can't reach MinIO**  
Check `hive.s3.endpoint` in `trino-values.yaml`. It must point to the MinIO ClusterIP service.

**Hive table location mismatch**  
Make sure the `LOCATION` in `create_tables.sql` exactly matches the bucket path you used in `mc cp`.

**Authentication error on MinIO**  
Verify `hive.s3.aws-access-key` and `hive.s3.aws-secret-key` match what's in `minio-values.yaml`.

**Parquet schema mismatch**  
If you edit the Python script, regenerate the Parquet files before re-creating Hive tables.

---

## Reference

- [Deploy MinIO and Trino with Kubernetes](https://www.min.io/blog/minio-trino-kubernetes)
- [Trino Hive connector docs](https://trino.io/docs/current/connector/hive.html)
- [MinIO Client (mc) quickstart](https://min.io/docs/minio/linux/reference/minio-mc.html)
