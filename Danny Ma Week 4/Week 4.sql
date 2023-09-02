 --A. Customer Nodes 

--How many unique nodes are there on the Data Bank system

SELECT COUNT(DISTINCT(node_id))as Number_of_Distinct_nodes
FROM customer_nodes;

--What is the number of nodes per region

SELECT COUNT(node_id) as Number_of_nodes, region_name
FROM customer_nodes
INNER JOIN regions 
ON regions.region_id = customer_nodes.region_id
GROUP BY region_name;

--How many customers are allocated to each region

SELECT COUNT(DISTINCT(customer_id)) as Number_of_customers, region_name
FROM customer_nodes
INNER JOIN regions 
ON regions.region_id = customer_nodes.region_id
GROUP BY region_name
ORDER BY Number_of_customers;

--How many days on average are customers reallocated to a different node
select AVG(DATEDIFF(DAY, start_date, end_date)) as avg_num_of_days
from customer_nodes
where end_date != '9999-12-31';


--What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

WITH date_diff AS
(
	SELECT cn.customer_id,
		   cn.region_id,
		   r.region_name,
		   DATEDIFF(DAY, start_date, end_date) AS reallocation_days
	FROM customer_nodes cn
	INNER JOIN regions r
	ON cn.region_id = r.region_id
	WHERE end_date != '9999-12-31'
)

SELECT DISTINCT region_id,
	   region_name,
	   PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY reallocation_days) OVER(PARTITION BY region_name) AS median,
	   PERCENTILE_CONT(0.8) WITHIN GROUP(ORDER BY reallocation_days) OVER(PARTITION BY region_name) AS percentile_80,
	   PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY reallocation_days) OVER(PARTITION BY region_name) AS percentile_95
FROM date_diff
ORDER BY region_name;


--B. Customer Transactions

--What is the unique count and total amount for each transaction type?

SELECT txn_type, SUM(txn_amount) as total_amount, COUNT(*) as Number_of_Transactions
FROM customer_transactions
GROUP BY txn_type
ORDER BY 2;

--What is the average total historical deposit counts and amounts for all customers

WITH COUNT_DEPOSIT_PER_CUSTOMER AS
		(
			SELECT count(*) AS COUNT_OF_DEPOSIT, 
					SUM(txn_amount) as TOTAL_AMOUNT,
				   customer_id
			FROM customer_transactions
			WHERE txn_type = 'deposit'
			GROUP BY customer_id
		)

SELECT AVG(COUNT_OF_DEPOSIT) as AVG_DEPOSIT_COUNT,
		AVG(TOTAL_AMOUNT) as AVG_AMOUNT
FROM COUNT_DEPOSIT_PER_CUSTOMER;

--OR

WITH column_1_2 AS 
		(
			SELECT count(*) AS COUNT_OF_DEPOSIT, 
				   count(distinct(customer_id)) as count_of_customers
			FROM customer_transactions
			WHERE txn_type = 'deposit'
		)

SELECT COUNT_OF_DEPOSIT/count_of_customers as AVG_DEPOSIT_COUNT
FROM column_1_2

--For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
 
SELECT month_id,	
      COUNT(DISTINCT(customer_id)) AS count_of_customers
FROM 
	(
		SELECT 
			COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_was_made,
			COUNT(CASE WHEN txn_type = 'purchase' THEN 1 END) AS purchase_was_done,
			COUNT(CASE WHEN txn_type = 'withdrawal' THEN 1 END) AS withdrawal_was_made,
			DATEPART(MONTH,txn_date) as month_id,
			customer_id
		FROM customer_transactions 
		GROUP BY customer_id, 
				 DATEPART(MONTH,txn_date)
	) AS customer_activity
WHERE deposit_was_made > 1
	 AND (purchase_was_done > 0 
		 OR withdrawal_was_made > 0)
GROUP BY month_id

--What is the closing balance for each customer at the end of the month?

SELECT 
		customer_spending_details.customer_id,
		month_id,
		SUM(customer_deposit_spending -customer_purchase_spending - customer_withdrawal_spending) OVER (PARTITION BY customer_spending_details.customer_id ORDER BY month_id) AS closing_balance
FROM
		(
			SELECT	
				customer_id,
				SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS customer_deposit_spending,
				SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS customer_purchase_spending,
				SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS customer_withdrawal_spending,
				DATEPART(MONTH,txn_date) AS month_id
			FROM customer_transactions
			GROUP BY customer_id, DATEPART(MONTH,txn_date)

		) AS customer_spending_details

--What is the percentage of customers who increase their closing balance by more than 5%?

SELECT 
		 csd.customer_id,
	     month_id,
		 SUM(customer_deposit_spending - customer_purchase_spending - customer_withdrawal_spending) OVER (PARTITION BY csd.customer_id ORDER BY month_id) AS closing_balance

FROM
		(
			SELECT	
				customer_id,
				SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS customer_deposit_spending,
				SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS customer_purchase_spending,
				SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS customer_withdrawal_spending,
				DATEPART(MONTH,txn_date) AS month_id
			FROM customer_transactions
			GROUP BY customer_id, DATEPART(MONTH,txn_date)

		) AS csd



WITH wahala AS(

SELECT 
		 csd.customer_id AS customer_id,
	     month_id,
		 SUM(customer_deposit_spending - customer_purchase_spending - customer_withdrawal_spending) OVER (PARTITION BY csd.customer_id ORDER BY month_id) AS closing_balance

FROM
		(
			SELECT	
				customer_id,
				SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS customer_deposit_spending,
				SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS customer_purchase_spending,
				SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS customer_withdrawal_spending,
				DATEPART(MONTH,txn_date) AS month_id
			FROM customer_transactions
			GROUP BY customer_id, DATEPART(MONTH,txn_date)

		) AS csd		
)

SELECT 
		customer_id, 
		month_id, 
		closing_balance, 
		LAG(closing_balance, 1, 0) OVER (partition by customer_id order by month_id) AS prev_month_closing_balance
FROM wahala