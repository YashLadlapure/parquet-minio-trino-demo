-- basic check on each table
SELECT * FROM hive.demo.sales LIMIT 10;
SELECT * FROM hive.demo.customers LIMIT 10;
SELECT * FROM hive.demo.products LIMIT 10;

-- join sales with customers
SELECT
  c.name        AS customer_name,
  c.city,
  s.amount
FROM hive.demo.sales s
JOIN hive.demo.customers c
  ON s.customer_id = c.customer_id
WHERE s.amount > 1000
ORDER BY s.amount DESC;

-- three-way join: sales + customers + products
SELECT
  c.name        AS customer,
  p.name        AS product,
  p.category,
  s.amount
FROM hive.demo.sales s
JOIN hive.demo.customers c ON s.customer_id = c.customer_id
JOIN hive.demo.products  p ON s.product_id  = p.product_id
ORDER BY s.amount DESC;

-- total spend per customer
SELECT
  c.name,
  SUM(s.amount) AS total_spent
FROM hive.demo.sales s
JOIN hive.demo.customers c ON s.customer_id = c.customer_id
GROUP BY c.name
ORDER BY total_spent DESC;

-- revenue by product category
SELECT
  p.category,
  COUNT(*)      AS order_count,
  SUM(s.amount) AS total_revenue
FROM hive.demo.sales s
JOIN hive.demo.products p ON s.product_id = p.product_id
GROUP BY p.category;
