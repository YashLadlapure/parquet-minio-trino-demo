import pandas as pd
import os

os.makedirs("output", exist_ok=True)

# sales.parquet
sales = pd.DataFrame({
    "order_id":    [1, 2, 3, 4, 5],
    "customer_id": [101, 102, 101, 103, 102],
    "product_id":  [201, 202, 203, 201, 203],
    "amount":      [1500.0, 800.0, 2300.0, 450.0, 1100.0]
})
sales.to_parquet("output/sales.parquet", index=False)

# customers.parquet
customers = pd.DataFrame({
    "customer_id": [101, 102, 103],
    "name":        ["Yash Ladlapure", "Priya Sharma", "Amit Kulkarni"],
    "city":        ["Pune", "Mumbai", "Nagpur"]
})
customers.to_parquet("output/customers.parquet", index=False)

# products.parquet
products = pd.DataFrame({
    "product_id": [201, 202, 203],
    "name":       ["Laptop", "Mouse", "Keyboard"],
    "category":   ["Electronics", "Accessories", "Accessories"]
})
products.to_parquet("output/products.parquet", index=False)

print("Parquet files generated in data/output/")
