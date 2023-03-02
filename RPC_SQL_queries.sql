--1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.


SELECT market
FROM gdb023.dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC"
GROUP BY market -- for removing duplicated "India" (there are 2 because of different channel)
ORDER BY market


/*2. What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg */

WITH up_2020 AS -- number of distinct products for 2020 fiscal year
(
SELECT COUNT(DISTINCT product_code) AS up_2020
FROM gdb023.fact_sales_monthly
WHERE fiscal_year = 2020
)
, up_2021 AS -- number of distinct products for 2021 fiscal year
(
SELECT COUNT(DISTINCT product_code) AS up_2021
FROM gdb023.fact_sales_monthly
WHERE fiscal_year = 2021
)
SELECT up_2020, up_2021, ROUND((up_2021-up_2020)/up_2020*100, 2) AS percentage_change
FROM up_2020
JOIN up_2021

/*3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
 The final output contains 2 fields, segment product_count */

SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM gdb023.dim_product
GROUP BY segment
ORDER BY product_count DESC

/*4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
 The final output contains these fields, segment product_count_2020 product_count_2021 difference */

WITH up_2020 AS -- number of distinct products for 2020 fiscal year grouped by segment
(
SELECT p. segment, COUNT(DISTINCT y.product_code) AS product_count_2020
FROM gdb023.fact_sales_monthly as y
JOIN gdb023.dim_product AS p ON y.product_code = p.product_code
WHERE fiscal_year = 2020
GROUP BY p.segment
)
, up_2021 AS -- number of distinct products for 2021 fiscal year grouped by segment
(
SELECT p.segment, COUNT(DISTINCT y.product_code) AS product_count_2021
FROM gdb023.fact_sales_monthly as y
JOIN gdb023.dim_product AS p ON y.product_code = p.product_code
WHERE fiscal_year = 2021
GROUP BY p.segment
)
SELECT up_2020.segment AS segment, product_count_2020, product_count_2021, product_count_2021-product_count_2020 AS difference
FROM up_2020
JOIN up_2021 ON up_2020.segment = up_2021.segment
ORDER BY difference DESC

/*5. Get the products that have the highest and lowest manufacturing costs.
 The final output should contain these fields, product_code product manufacturing_cost */


(SELECT p.product_code, p.product, m.manufacturing_cost -- first query to fetch minimum
FROM gdb023.dim_product AS p
JOIN gdb023.fact_manufacturing_cost AS m ON p.product_code = m.product_code
WHERE m.manufacturing_cost = (SELECT MIN(m.manufacturing_cost))
ORDER BY m.manufacturing_cost ASC
LIMIT 1)
UNION ALL -- to fetch both queries in one tabel
(SELECT p.product_code, p.product, m.manufacturing_cost -- second query to fetch maximum
FROM gdb023.dim_product AS p
JOIN gdb023.fact_manufacturing_cost AS m ON p.product_code = m.product_code
WHERE m.manufacturing_cost = (SELECT MAX(m.manufacturing_cost))
ORDER BY m.manufacturing_cost DESC
LIMIT 1)


/* 6. Generate a report which contains the top 5 customers who received an average high 
pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields, customer_code customer average_discount_percentage */

SELECT c.customer_code, c.customer, ROUND(i.pre_invoice_discount_pct*100, 1) AS average_discount_percentage
FROM gdb023.dim_customer AS c
JOIN gdb023.fact_pre_invoice_deductions AS i ON c.customer_code = i.customer_code
WHERE i.fiscal_year = 2021 AND c.market = "India"
ORDER BY average_discount_percentage DESC
LIMIT 5

/* 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.
 This analysis helps to get an idea of low and high-performing months and take strategic decisions.
 The final report contains these columns: Month Year Gross sales Amount */
 

SELECT MONTH(s.date) AS month, YEAR(s.date) AS year, ROUND(SUM(s.sold_quantity * gp.gross_price), 2) AS gross_sales_amount
FROM gdb023.fact_sales_monthly AS s
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
WHERE customer = "Atliq Exclusive"
GROUP BY 1,2
ORDER BY 2,1


/* 8. In which quarter of 2020, got the maximum total_sold_quantity?
 The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity */
 
SELECT SUM(sold_quantity) AS total_sold_quantity,
CASE 
	WHEN MONTH(date) BETWEEN 1 AND 3 THEN 'QUARTER 1'
    WHEN MONTH(date) BETWEEN 4 AND 6 THEN 'QUARTER 2'
    WHEN MONTH(date) BETWEEN 7 AND 9 THEN 'QUARTER 3'
    ELSE 'QUARTER 4'
END AS Quarter -- grouping months for quarters
FROM gdb023.fact_sales_monthly
WHERE YEAR(date) = 2020
GROUP BY 2
ORDER BY 1 DESC

/*9. Which channel helped to bring more gross sales in the fiscal year 2021 
and the percentage of contribution? 
The final output contains these fields, channel gross_sales_mln percentage */

SELECT sub.channel, ROUND(sub.gross_sales_mln/SUM(sub.gross_sales_mln) OVER() *100, 2) AS percentage -- OVER() clause to provide percentage for all channels
    FROM ( -- subquery to provide total gross sales in millions qrouped by channel
SELECT c.channel AS channel, ROUND(SUM(s.sold_quantity*gp.gross_price/1000000), 2) AS gross_sales_mln
FROM gdb023.dim_customer AS c
JOIN gdb023.fact_sales_monthly AS s ON c.customer_code = s.customer_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
GROUP BY c.channel) AS sub


/*10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields, division product_code product total_sold_quantity rank_order */

SELECT * FROM ( -- subquery to provide all needed data
SELECT p.division, p.product_code, p.product, SUM(s.sold_quantity) AS total_sold,
RANK() OVER (PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order -- window function for rank of products in every division
FROM gdb023.dim_product AS p
JOIN gdb023.fact_sales_monthly AS s ON p.product_code = s.product_code
WHERE s.fiscal_year = 2021
GROUP BY 1, 2, 3) AS x
WHERE x.rank_order <= 3 -- fetching only top 3 of products for ecery division


--Add 1. Top and bottom 5 customers by total gross sales in millions in fiscal year 2021

SELECT c.customer, ROUND(SUM(s.sold_quantity*gp.gross_price/1000000),2) AS gross_sales_mln
FROM gdb023.fact_sales_monthly AS s
JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
WHERE s.fiscal_year = 2021
GROUP BY c.customer
ORDER BY gross_sales_mln DESC;

SELECT c.customer, ROUND(SUM(s.sold_quantity*gp.gross_price/1000000),2) AS gross_sales_mln
FROM gdb023.fact_sales_monthly AS s
JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
WHERE s.fiscal_year = 2021
GROUP BY c.customer
ORDER BY gross_sales_mln ASC


--Add 2. Total profit by market best and worst 5 markets

SELECT c.market, ROUND((SUM(s.sold_quantity*gp.gross_price)-SUM(s.sold_quantity*m.manufacturing_cost))/1000000, 2) AS best_profit
FROM gdb023.fact_sales_monthly AS s
JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
JOIN gdb023.fact_manufacturing_cost AS m ON s.product_code = m.product_code
WHERE s.fiscal_year = 2021
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

SELECT c.market, ROUND((SUM(s.sold_quantity*gp.gross_price)-SUM(s.sold_quantity*m.manufacturing_cost))/1000000, 2) AS best_profit
FROM gdb023.fact_sales_monthly AS s
JOIN gdb023.dim_customer AS c ON s.customer_code = c.customer_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
JOIN gdb023.fact_manufacturing_cost AS m ON s.product_code = m.product_code
WHERE s.fiscal_year = 2021
GROUP BY 1
ORDER BY 2 ASC
LIMIT 5

--Add 3. Worst and best 5 profits by product

SELECT p.product, ROUND((SUM(s.sold_quantity*gp.gross_price)-SUM(s.sold_quantity*m.manufacturing_cost))/1000000, 2) AS best_profit
FROM gdb023.dim_product AS p
JOIN gdb023.fact_sales_monthly AS s ON p.product_code = s.product_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
JOIN gdb023.fact_manufacturing_cost AS m ON s.product_code = m.product_code
WHERE s.fiscal_year = 2021
GROUP BY 1
ORDER BY 2 ASC
LIMIT 5;

SELECT p.product, ROUND((SUM(s.sold_quantity*gp.gross_price)-SUM(s.sold_quantity*m.manufacturing_cost))/1000000, 2) AS best_profit
FROM gdb023.dim_product AS p
JOIN gdb023.fact_sales_monthly AS s ON p.product_code = s.product_code
JOIN gdb023.fact_gross_price AS gp ON s.product_code = gp.product_code
JOIN gdb023.fact_manufacturing_cost AS m ON s.product_code = m.product_code
WHERE s.fiscal_year = 2021
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5