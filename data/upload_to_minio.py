from minio import Minio
from minio.error import S3Error
from pathlib import Path

client = Minio(
    "localhost:9000",
    access_key="minioadmin",
    secret_key="minioadmin",
    secure=False
)

bucket_name = "demo-bucket"

files_to_upload = [
    ("output/sales.parquet",     "data/sales/sales.parquet"),
    ("output/customers.parquet", "data/customers/customers.parquet"),
    ("output/products.parquet",  "data/products/products.parquet"),
]

try:
    if not client.bucket_exists(bucket_name):
        client.make_bucket(bucket_name)
        print(f"Created bucket: {bucket_name}")
    else:
        print(f"Bucket already exists: {bucket_name}")

    for local_file, object_name in files_to_upload:
        file_path = Path(local_file)
        if not file_path.exists():
            print(f"File not found, skipping: {file_path}")
            continue

        client.fput_object(
            bucket_name=bucket_name,
            object_name=object_name,
            file_path=str(file_path)
        )
        print(f"Uploaded: {file_path} -> {bucket_name}/{object_name}")

    print("\nAll files uploaded. Check MinIO at http://localhost:9001")

except S3Error as err:
    print("MinIO error:", err)
