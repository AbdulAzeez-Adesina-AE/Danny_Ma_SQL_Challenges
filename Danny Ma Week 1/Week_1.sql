-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	customer_id, 
	sum(price) AS Total_Spent
FROM sales AS ss
	LEFT JOIN menu AS me
	ON ss.product_id = me.product_id
GROUP BY customer_id

-- 2. How many days has each customer visited the restaurant?

SELECT 
	customer_id, 
	COUNT(DISTINCT order_date) AS Times_Visited
FROM sales AS ss
GROUP BY customer_id
ORDER BY Times_Visited DESC


-- 3. What was the first item from the menu purchased by each customer?

WITH AGBA AS(
SELECT 
	customer_id,
	order_date, 
	product_name,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS o_rank
FROM sales
	INNER JOIN menu
	ON sales.product_id = menu.product_id
)
SELECT 
	customer_id, 
	product_name
FROM AGBA
WHERE o_rank = 1


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT 
	TOP 1 
		product_name, 
		COUNT(order_date) AS Total_orders
FROM sales AS ss
	INNER JOIN menu AS me
	ON ss.product_id = me.product_id
GROUP BY product_name
ORDER BY count (order_date) DESC

--line of code to determine how many times the highest seeling product was bought by each customers
SELECT 
	customer_id, 
	COUNT(order_date) AS number_of_orders
FROM sales AS ss
	INNER JOIN menu AS me
ON ss.product_id = me.product_id
WHERE product_name = (
		SELECT 
			TOP 1 
				product_name
		FROM sales AS ss
			INNER JOIN menu AS me
			ON ss.product_id = me.product_id
		GROUP BY product_name
		ORDER BY COUNT (order_date) DESC
					)
GROUP BY customer_id


-- 5. Which item was the most popular for each customer?

WITH BUNNY AS(
		SELECT 
			product_name, 
			customer_id, 
			COUNT(order_date) AS Total_orders,
			RANK()OVER(PARTITION BY customer_id ORDER BY COUNT(order_date) DESC) AS o_rank,
			ROW_NUMBER()OVER(PARTITION BY customer_id ORDER BY COUNT(order_date) DESC) AS o_rank1
		FROM sales AS ss
			INNER JOIN menu AS me
			ON ss.product_id = me.product_id
		GROUP BY product_name, customer_id
)
SELECT Customer_id, Product_name, Total_orders
FROM BUNNY
WHERE O_RANK = 1


-- 6. Which item was purchased first by the customer after they became a member?

WITH BERRY AS (
	SELECT 
		sales.customer_id, 
		join_date, order_date, 
		sales.product_id, 
		product_name,
		RANK()OVER(PARTITION BY sales.customer_id ORDER BY (order_date) ) AS o_rank1
	FROM sales
		LEFT JOIN members
		ON sales.customer_id = members.customer_id
		INNER JOIN menu
		ON sales.product_id = menu.product_id
	WHERE order_date>join_date
								)
SELECT customer_id, product_name
FROM BERRY
WHERE o_rank1 = 1

-- 7. Which item was purchased just before the customer became a member?

WITH BIG_BERRY AS (
	SELECT 
		sales.customer_id, 
		join_date, order_date, 
		sales.product_id, 
		product_name,
		RANK()OVER(PARTITION BY members.customer_id ORDER BY (order_date) ) AS o_rank1,
		ROW_NUMBER()OVER(PARTITION BY members.customer_id ORDER BY (order_date) ) AS o_rank2
	FROM sales
		INNER JOIN members
		ON sales.customer_id = members.customer_id
		INNER JOIN menu
		ON sales.product_id = menu.product_id
	WHERE order_date<join_date
						    	)
SELECT customer_id, product_name
FROM BIG_BERRY
WHERE o_rank1 = 1

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT 
	sales.customer_id, 
	COUNT(order_date) AS number_of_items,
	SUM(price) AS total_spent
FROM sales
	INNER JOIN members
	ON sales.customer_id = members.customer_id
	INNER JOIN menu
	ON sales.product_id = menu.product_id
WHERE order_date<join_date
GROUP BY sales.customer_id

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT 
	customer_id,
	SUM(CASE
			WHEN product_name = 'sushi' THEN price * 10 * 2
		    ELSE price * 10
		    END) AS points_won
FROM sales
	INNER JOIN menu
	ON sales.product_id = menu.product_id
GROUP BY customer_id

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT 
	sales.customer_id,
	SUM(CASE
			WHEN  order_date BETWEEN members.join_date AND DATEADD(DAY,6,members.join_date) THEN price * 10 * 2
			WHEN product_name ='sushi' THEN price * 10 * 2
		    ELSE price * 10
		    END) AS points_won
FROM sales AS sales
	INNER JOIN menu AS MENU
	ON sales.product_id = menu.product_id
	INNER JOIN members AS members
	ON sales.customer_id = members.customer_id
WHERE DATE_BUCKET(MONTH,1,order_date) = '2021-01-01'
GROUP BY sales.customer_id


--GENERAL TABLE
SELECT 
	*
FROM sales AS sales
	INNER JOIN menu
	ON sales.product_id = menu.product_id
	INNER JOIN members AS members
	ON sales.customer_id = members.customer_id
