--1.Create ROLE ‘superstore’
CREATE ROLE superstore;

--2.Create database ‘superstore_sales’ with owner ‘superstore’
CREATE DATABASE superstore_sales WITH OWNER superstore;

SET ROLE TO superstore;

--3.In db ‘superstore_sales’, create a schema ‘superschema’ AUTHORIZATION superstore
CREATE SCHEMA superschema AUTHORIZATION superstore;

SET search_path = superschema;

-- CREATE TABLE Orders
CREATE TABLE orders (
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50),
    market VARCHAR(50),
    region VARCHAR(50),
    product_id VARCHAR(100),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(255),
    sales FLOAT,
    quantity INT,
    discount FLOAT,
    profit FLOAT,
    shipping_cost FLOAT,
    order_priority VARCHAR(50),
    year INT
);

-- -- CREATE TABLE Returns
-- CREATE TABLE returns (
-- 	returned BOOLEAN,
-- 	order_id VARCHAR(50),
-- 	market VARCHAR(50)
-- )

-- Import data from file csv
COPY orders(order_id, order_date, ship_date, ship_mode, customer_name, segment, state, country, market, region,
product_id, category, sub_category, product_name, sales, quantity, discount, profit, shipping_cost, order_priority, year)
FROM 'D:/Project/My Project/superstore_sales_clean.csv'
DELIMITER ',' CSV HEADER;

COPY returns(returned, order_id, market)
FROM 'D:/Project/My Project/Returns.csv'
DELIMITER ',' CSV HEADER;

-- Explore All Object in the Database
SELECT * FROM INFORMATION_SCHEMA.TABLES;

---Explore All Columns in the Database
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'orders';

SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'returns';


--***********************QUERY************************
SELECT * FROM orders
--*************** 1. REVENUE AND PROFIT OVERVIEW ****************

--1.1 Total revenue and total profit
SELECT
    ROUND(SUM(sales)::NUMERIC , 2) AS total_sales,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders;

--1.2 Revenue and porfit by year
SELECT
	DATE_TRUNC('year', order_date) AS year,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit):: NUMERIC, 2) AS total_profits
FROM orders
GROUP BY DATE_TRUNC('year', order_date)
ORDER BY DATE_TRUNC('year', order_date);

--1.3 Average profit per order
SELECT
	ROUND(AVG(profit)::NUMERIC, 2) AS avg_profit_per_order
FROM(
	SELECT
		order_id,
		SUM(profit) AS profit
	FROM orders
	GROUP BY order_id
)

-- 1.4 Average profit margin of the whole company by region
SELECT
	region,
	ROUND((SUM(profit) / SUM(sales) * 100)::NUMERIC, 2) AS profit_margin
FROM orders
GROUP BY region
ORDER BY profit_margin DESC;


--1.5 Average number of orders, average orders quantity, and average sales per year
SELECT
	year,
	COUNT(DISTINCT order_id) / COUNT(DISTINCT year) AS avg_orders,
	ROUND(AVG(quantity)::NUMERIC, 2) AS avg_order_quantity,
	ROUND(AVG(sales):: NUMERIC, 2) AS avg_sales
FROM orders
GROUP BY year
ORDER BY year

--1.6 The total profits and total sales per quarter
SELECT 
	date_part('year', order_date) AS year,
	CASE
		WHEN date_part('month', order_date) IN (1, 2, 3) THEN 'Q1'
		WHEN date_part('month', order_date) IN (4, 5, 6) THEN 'Q2'
		WHEN date_part('month', order_date) IN (7, 8, 9) THEN 'Q3'
		ELSE 'Q4'
	END AS quarter,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY date_part('year', order_date), quarter 
ORDER BY date_part('year', order_date), quarter

--1.7 Average profit by sub-category
SELECT
	sub_category,
	COUNT(DISTINCT product_id) AS num_products,
	ROUND(AVG(profit)::NUMERIC, 2) AS avg_profit,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY sub_category
ORDER BY avg_profit DESC;

--1.8 Number of orders by day of week and month of year
SELECT
  TO_CHAR(order_date, 'YYYY-MM') AS year_month,
  CASE EXTRACT(DOW FROM order_date)::int
    WHEN 0 THEN 'Sunday'
    WHEN 1 THEN 'Monday'
    WHEN 2 THEN 'Tuesday'
    WHEN 3 THEN 'Wednesday'
    WHEN 4 THEN 'Thursday'
    WHEN 5 THEN 'Friday'
    WHEN 6 THEN 'Saturday'
  END AS day_of_week,
  COUNT(DISTINCT order_id) AS num_orders
FROM orders
GROUP BY 1, 2
ORDER BY 1, 2;

-- 1.9 Top 10 orders with the most losses
SELECT 
    order_id,
    customer_name,
    SUM(sales) AS total_sales,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY order_id, customer_name
HAVING SUM(profit) < 0
ORDER BY total_profit ASC
LIMIT 10;

--1.10 Loss order rate
SELECT 
  ROUND(
    COUNT(CASE WHEN profit < 0 THEN 1 END)::decimal 
    / NULLIF(COUNT(*), 0), 4
  ) AS loss_order_rate
FROM orders;


--*************** 2. CUSTOMER *******************

--2.1 Total Customers, Orders, and Average Value Per Customer
SELECT 
    COUNT(DISTINCT customer_name) AS total_customers,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(sales)::NUMERIC / COUNT(DISTINCT customer_name), 2) AS avg_sales_per_customer
FROM orders;

--2.2 Top 10 customers with highest total revenue
SELECT
	customer_name,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY customer_name
ORDER BY total_sales DESC
LIMIT 10;

--2.3 Top 10 customers with highest total profit
SELECT
	customer_name,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY customer_name
ORDER BY total_profit DESC
LIMIT 10;

--2.4 Top 10 customers with the most orders
SELECT
	customer_name,
	COUNT(DISTINCT order_id) AS num_orders
FROM orders
GROUP BY customer_name
ORDER BY num_orders DESC
LIMIT 10;

--2.5 Customer segementation by profit behavior
SELECT 
	customer_name,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	CASE 
		WHEN SUM(profit) < 0 THEN 'Loss'
		WHEN SUM(profit) < 500 THEN 'Low profit'
		WHEN SUM(profit) < 1500 THEN 'Moderate profit'
		ELSE 'High profit'
	END AS profit_group
FROM orders
GROUP BY customer_name
ORDER BY total_profit;

--2.6 RFM – Recency, Frequency, Monetary
WITH customer_orders AS (
	SELECT 
		customer_name,
		MAX(order_date) AS last_order_date,
		COUNT(DISTINCT order_id) AS frequency,
		SUM(sales) AS monetary
	FROM orders
	GROUP BY customer_name
),
rfm AS (
	SELECT
		customer_name,
		('2024-12-31'::date - last_order_date) AS recency,
		frequency,
		monetary
	FROM customer_orders
)
SELECT * 
FROM rfm
ORDER BY
	recency,
	frequency DESC,
	monetary DESC
LIMIT 10;

--2.6 Customer segmentation by segment & performance
SELECT
	segment,
	COUNT(DISTINCT customer_name) AS num_customers,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND((SUM(profit)/ NULLIF(SUM(sales), 0))::NUMERIC * 100, 2) AS profit_margin
FROM orders
GROUP BY segment
ORDER BY total_sales DESC;

--2.7 Loss-Making Customers
SELECT
	customer_name,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY customer_name 
HAVING SUM(profit) < 0
ORDER BY total_profit 
LIMIT 10;

--2.8 Customer buying behavior by category
SELECT
	customer_name,
	category,
	COUNT(DISTINCT order_id) AS num_orders,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY customer_name, category
ORDER BY 
	customer_name,
	total_sales DESC
	
--2.9 Customer retention rate year over year
WITH yearly_customer AS (
	SELECT
		customer_name,
		year
	FROM orders
	GROUP BY customer_name, year
),
retention AS(
	SELECT
		curr.year,
		COUNT(DISTINCT curr.customer_name) AS customer_this_year,
		COUNT(DISTINCT prev.customer_name) AS returning_customers
	FROM yearly_customer curr
	LEFT JOIN yearly_customer prev
	ON curr.customer_name = prev.customer_name 
	AND curr.year = prev.year + 1
	GROUP BY curr.year
)
SELECT
	year,
	customer_this_year,
	returning_customers,
	ROUND(returning_customers * 100.0 / customer_this_year, 2) AS retention_rate
FROM retention
ORDER BY year;


--************************** 3. Product & Category **********************

-- 3.1. Category, sun catgory and product name
SELECT DISTINCT category, sub_category, product_name
FROM orders
ORDER BY 1,2,3

--3.2 Names and prices of all products
SELECT 
	product_id,
	product_name,
	MAX(sales) AS max_price,
	AVG(sales) AS avg_price,
	MIN(sales) AS min_price
FROM orders
GROUP BY product_id, product_name

--3.3 Top 10 best selling products by quantity
SELECT
	product_name,
	SUM(quantity) AS total_quantity
FROM orders
GROUP BY product_name
ORDER BY total_quantity DESC
LIMIT 10;

--3.4 Top 10 products with highest revenue
SELECT
	product_name,
	SUM(sales) AS total_sales
FROM orders
GROUP BY product_name
ORDER BY total_sales DESC
LIMIT 10;

--3.5 Top 10 products with highest profit
SELECT
	product_name,
	SUM(profit) AS total_profit
FROM orders
GROUP BY product_name
ORDER BY total_profit DESC
LIMIT 10;

--3.6 Top 10 products with the most losses
SELECT 
    product_name,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit
FROM orders
GROUP BY product_name
HAVING SUM(profit) < 0
ORDER BY total_profit ASC
LIMIT 10;

--3.7 Revenue & Profit by Category and Sub-Category
SELECT
	category,
	sub_category,
	SUM(sales) AS total_sales,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND((SUM(profit)/ NULLIF(SUM(sales), 0))::NUMERIC * 100, 2) AS profit_margin
FROM orders
GROUP BY category, sub_category
ORDER BY total_sales DESC;

--3.8 Average discount by sub-category
SELECT 
    sub_category,
    ROUND(AVG(discount)::NUMERIC, 2) AS avg_discount,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY sub_category
ORDER BY avg_discount DESC;

--3.9 Lowest profit product in each sub-category
SELECT category, sub_category, product_name, total_profit
FROM (
	SELECT
		category,
		sub_category,
		product_name,
		ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
		RANK() OVER(PARTITION BY sub_category ORDER BY SUM(profit)) AS rank
	FROM orders
	GROUP BY category,sub_category, product_name
	 )t
WHERE rank = 1;

--3.10 The relationship between sales volume and profit
SELECT 
    sub_category,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
    ROUND((SUM(profit)/NULLIF(SUM(quantity), 0))::NUMERIC, 2) AS profit_per_unit
FROM orders
GROUP BY sub_category
ORDER BY profit_per_unit DESC;

--3.11 The top 3 most purchased products by month for each year
WITH monthly_sales AS(
	SELECT
		year,
		EXTRACT(MONTH FROM order_date) AS month,
		product_name,
	SUM(quantity) AS total_quantity
	FROM orders
	GROUP BY year, month, product_name
),
ranked_products AS(
	SELECT 
		*,
		RANK() OVER(PARTITION BY year, month ORDER BY total_quantity DESC) AS product_rank
	FROM monthly_sales
)
SELECT
	year,
	month,
	product_name,
	total_quantity
FROM ranked_products
WHERE product_rank <= 3
ORDER BY year, month, product_rank;


-- ************************** 4. TRANSPORT **********************

--4.1 Average delivery time
SELECT
	ROUND(AVG(ship_date - order_date)::NUMERIC , 2) AS avg_delivery_days
FROM orders;

--4.2 Average delivery time by Ship Mode
SELECT
	ship_mode,
	ROUND(AVG(ship_date - order_date)::NUMERIC , 2) AS avg_delivery_days,
	COUNT(*) AS num_orders
FROM orders
GROUP BY ship_mode
ORDER BY avg_delivery_days

--4.3 Total shipping cost by Ship Mode
SELECT
	ship_mode,
	ROUND(SUM(shipping_cost)::NUMERIC, 2) AS total_shipping_cost,
	ROUND(AVG(shipping_cost)::NUMERIC, 2) AS avg_shipping_cost
FROM orders
GROUP BY ship_mode
ORDER BY total_shipping_cost DESC;

--4.4 The relationship between shipping costs and profits
SELECT 
  order_id,
  ROUND(SUM(shipping_cost)::NUMERIC, 2) AS total_shipping_cost,
  ROUND(SUM(profit)::NUMERIC,2) AS total_profit,
  ROUND((SUM(profit)/NULLIF(SUM(sales),0))::NUMERIC*100, 2) AS profit_margin
FROM orders
GROUP BY order_id
ORDER BY total_shipping_cost DESC;

--4.5 Average Profit by Ship Mode
SELECT 
    ship_mode,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
    ROUND((SUM(profit)/NULLIF(COUNT(*), 0))::NUMERIC, 2) AS avg_profit_per_item,
    ROUND((SUM(profit)/NULLIF(SUM(sales),0))::NUMERIC*100, 2) AS profit_margin
FROM orders
GROUP BY ship_mode
ORDER BY total_profit DESC;

--4.6 Orders with high shipping costs but low profits
SELECT 
	order_id,
	customer_name,
	shipping_cost, 
	sales,
	profit
FROM orders
WHERE shipping_cost > 50 AND profit < 100
ORDER BY shipping_cost DESC;

--4.7 Shipping Mode há a high of lost orders
SELECT 
    ship_mode,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS loss_orders,
    ROUND(SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END)*100.0/COUNT(*), 2) AS loss_pct
FROM orders
GROUP BY ship_mode
ORDER BY loss_pct DESC;

--4.8 Orders with shipping costs exceeding 30% of revenue
SELECT
	order_id,
	SUM(sales) AS total_sales,
	ROUND(SUM(shipping_cost)::NUMERIC,2) AS total_shipping_cost,
	ROUND((SUM(shipping_cost)/NULLIF(SUM(sales), 0)*100)::NUMERIC,2) AS shipping_cost_pct
FROM orders
GROUP BY order_id
HAVING ROUND((SUM(shipping_cost)/NULLIF(SUM(sales), 0)*100)::NUMERIC,2) > 30
ORDER BY shipping_cost_pct DESC;

--4.9 Delivery time per order
SELECT 
	order_id,
	ship_date,
	order_date,
	(ship_date - order_date) AS delivery_days,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY order_id, ship_date, order_date
ORDER BY delivery_days DESC;

--4.10 Number of orders by priority level
SELECT 
    order_priority,
    COUNT(DISTINCT order_id) AS num_orders,
    SUM(sales) AS total_sales,
    ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY order_priority
ORDER BY num_orders DESC;


--********************************* 5. Timeline & Trend Analysis *****************

--5.1 Analyze Sales Performance Over Time
SELECT
	year,
	SUM(sales) AS total_sales,
	COUNT(DISTINCT customer_name) AS total_customer,
	SUM(quantity) AS total_quantity,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
WHERE order_date IS NOT NULL
GROUP BY year
ORDER BY year;

--5.2 Monthly revenue in each year
SELECT
	year,
	EXTRACT(MONTH FROM order_date) AS month,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
WHERE order_date IS NOT NULL
GROUP BY year, month
ORDER BY year, month;

--5.3 Numer of orders per month
SELECT
	TO_CHAR(order_date, 'MM-YYYY') AS month,
	COUNT(DISTINCT order_id) AS num_orders
FROM orders
GROUP BY month
ORDER BY month;

--5.4 Revenue growth year over year (YoY)
WITH yearly_sales AS(
	SELECT
		year,
		SUM(sales) AS total_sales
	FROM orders
	GROUP BY year
),
growth AS(
	SELECT
		year,
		total_sales,
		LAG(total_sales) OVER(ORDER BY year) AS pre_sales
	FROM yearly_sales
)
SELECT 
	year,
	total_sales,
	ROUND(((total_sales - pre_sales) / NULLIF(pre_sales, 0) * 100)::NUMERIC,2) AS sales_growth
FROM growth;

--5.5 Top 3 months with highest revenue each year
SELECT 
	year, 
	month, 
	monthly_sales
FROM(
	SELECT
		year,
		EXTRACT(MONTH FROM order_date) AS month,
		SUM(sales) AS monthly_sales,
		RANK() OVER (PARTITION BY year ORDER BY SUM(sales) DESC) AS sales_rank
	FROM orders
	GROUP BY year, month
) t
WHERE sales_rank <= 3
ORDER BY year, month;

--5.6 Best selling products every year
SELECT
	year,
	product_name,
	total_quantity
FROM(
	SELECT
		year,
		product_name,
		SUM(quantity) AS total_quantity,
		RANK() OVER(PARTITION BY year ORDER BY SUM(quantity) DESC) AS rank
	FROM orders
	GROUP BY year, product_name
)t
WHERE rank = 1;

--5.7 Most Profitable Products Each Quarter
WITH sales_by_quarter AS(
SELECT 
	year,
	CASE
		WHEN date_part('month', order_date) IN (1, 2, 3) THEN 'Q1'
		WHEN date_part('month', order_date) IN (4, 5, 6) THEN 'Q2'
		WHEN date_part('month', order_date) IN (7, 8, 9) THEN 'Q3'
		ELSE 'Q4'
	END AS quarter,
	product_name,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY year, quarter, product_name
),
ranked_products AS(
	SELECT 
		*,
		RANK() OVER(PARTITION BY year, quarter ORDER BY total_profit DESC) AS rank
	FROM sales_by_quarter
)
SELECT 
	year,
	quarter,
	product_name,
	total_profit
FROM ranked_products
WHERE rank = 1
ORDER BY year, quarter;


-- ************************ 6. Region, Market and State **********************

-- 6.1. What region generates the highest sales and profits ?
SELECT
	region,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit	
FROM orders
GROUP BY region
ORDER BY total_sales DESC;

-- 6.2  What state brings in the highest sales and profits?
SELECT
	state,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND((SUM(profit) / SUM(sales) * 100)::NUMERIC, 2) AS profit_margin
FROM orders
GROUP BY state
ORDER BY total_sales DESC
LIMIT 10;

--6.3 Revenue and profit by Market
SELECT 
	market,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND((SUM(profit) / SUM(sales) * 100)::NUMERIC, 2) AS profit_margin
FROM orders
GROUP BY market
ORDER BY total_sales DESC;

--6.4 Revenue and profit by State
SELECT 
	state,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND((SUM(profit) / SUM(sales) * 100)::NUMERIC, 2) AS profit_margin
FROM orders
GROUP BY state
ORDER BY total_sales DESC;

--6.5 States with negative returns
SELECT 
	state,
	SUM(sales) AS total_sales,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit
FROM orders
GROUP BY state
HAVING SUM(profit) < 0
ORDER BY total_profit;

--6.6 Highest profit state every year
SELECT 
	year,
	state,
	total_profit
FROM(
	SELECT
		year,
		state,
		ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
		RANK() OVER(PARTITION BY year ORDER BY SUM(profit) DESC) AS rank
	FROM orders
	GROUP BY year, state
)t
WHERE rank = 1;

--6.7 Top 5 best selling products in each region
SELECT 
	region,
	product_name,
	total_quantity
FROM(
	SELECT
		region,
		product_name,
		SUM(quantity) AS total_quantity,
		RANK() OVER(PARTITION BY region ORDER BY SUM(quantity) DESC) AS rank
	FROM orders
	GROUP BY region, product_name
)t
WHERE rank <= 5
ORDER BY region, rank;

--6.8 Number of customers by region
SELECT
	region,
	COUNT(DISTINCT customer_name) AS num_customers
FROM orders
GROUP BY region
ORDER BY num_customers DESC;

--6.9 The number of orders by Market and Segment
SELECT
	market,
	segment,
	COUNT(DISTINCT order_id) AS num_orders,
	SUM(sales) AS total_sales
FROM orders
GROUP BY market, segment
ORDER BY market, num_orders DESC;





