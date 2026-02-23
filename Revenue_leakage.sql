-- =====================================================================
-- Purpose:
-- Analyze product-level profitability to identify potential revenue
-- leakage. Revenue, cost, and profit are calculated per order line to
-- detect low‑margin or negative‑margin transactions.
-- =====================================================================

-- Step 1:
-- Compute revenue, cost, and profit for each order line.
-- Used to check for zero or negative profit (none found in this dataset).
WITH order_profit AS (
    SELECT
        orderkey,
        linenumber,
        productkey,
        quantity,
        unitprice,
        netprice,
        unitcost,
        exchangerate,
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND(((netprice::numeric * quantity) - (unitcost::numeric * quantity)), 2) AS profit
    FROM sales
)

SELECT *
FROM order_profit
WHERE profit <= 0
LIMIT 10;

-- No rows returned → all transactions show positive profit.
-- Next: find the min/max profit range for context.
WITH order_profit AS (
    SELECT
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND(((netprice::numeric * quantity) - (unitcost::numeric * quantity)), 2) AS profit
    FROM sales
)
SELECT 
    MIN(profit) AS min_profit,
    MAX(profit) AS max_profit
FROM order_profit;

-- Step 2:
-- Categorize each order line into margin bands: 

-- note: after serveral queries all of the profit values are between 25-75, so we can use that as a basis for our margin bands.
--but first i want to get a count of the items in the margins to better understand how to proceed with messuring the data.

WITH order_profit AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND(((netprice::numeric * quantity) - (unitcost::numeric * quantity)), 2) AS profit
    FROM sales
),

margin_bands AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        revenue,
        cost,
        profit,
        CASE
            WHEN revenue = 0 THEN 'No Revenue'
            WHEN (profit / revenue) < 0.25 THEN '< 25%'
            WHEN (profit / revenue) BETWEEN 0.25 AND 0.35 THEN '25% - 35%'
            WHEN (profit / revenue) BETWEEN 0.35 AND 0.45 THEN '35% - 45%'
            WHEN (profit / revenue) BETWEEN 0.45 AND 0.55 THEN '45% - 55%'
            WHEN (profit / revenue) BETWEEN 0.55 AND 0.65 THEN '55% - 65%'
            WHEN (profit / revenue) BETWEEN 0.65 AND 0.75 THEN '65% - 75%'
            WHEN (profit / revenue) > 0.75 THEN '> 75%'
        END AS margin_band
    FROM order_profit
)

SELECT
    margin_band,
    COUNT(*) AS item_count
FROM margin_bands
GROUP BY margin_band
ORDER BY margin_band;

--here is where i had to pivot the orginal task. I was working towards finding where procuts were loosing money on sales. 
--even including shipping and handling costs, all of the products in this dataset are showing a profit.

-- Pivot:
-- Since all products fall within healthy margin bands and no loss-making items were found,
-- we're shifting the analysis from individual product margins to category-level profitability.
-- First step: join product → subcategory → category to evaluate which categories generate
-- the most revenue, profit, and strongest average margins.


-- Step 1 of the pivot:
-- Aggregate profitability at the product category level to identify which categories
-- generate the most revenue, profit, and strongest average margins.

WITH order_profit AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND(((netprice::numeric * quantity) - (unitcost::numeric * quantity)), 2) AS profit
    FROM sales
),

margin_bands AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        revenue,
        cost,
        profit,
        CASE
            WHEN revenue = 0 THEN 'No Revenue'
            WHEN (profit / revenue) < 0.25 THEN '< 25%'
            WHEN (profit / revenue) BETWEEN 0.25 AND 0.35 THEN '25% - 35%'
            WHEN (profit / revenue) BETWEEN 0.35 AND 0.45 THEN '35% - 45%'
            WHEN (profit / revenue) BETWEEN 0.45 AND 0.55 THEN '45% - 55%'
            WHEN (profit / revenue) BETWEEN 0.55 AND 0.65 THEN '55% - 65%'
            WHEN (profit / revenue) BETWEEN 0.65 AND 0.75 THEN '65% - 75%'
            WHEN (profit / revenue) > 0.75 THEN '> 75%'
        END AS margin_band
    FROM order_profit
)

SELECT
    pc.categoryname,
    COUNT(*) AS total_items,
    SUM(mb.revenue) AS total_revenue,
    SUM(mb.cost) AS total_cost,
    SUM(mb.profit) AS total_profit,
    AVG(mb.profit / mb.revenue) AS avg_margin
FROM margin_bands mb
JOIN product p
    ON mb.productkey = p.productkey
JOIN productsubcategory ps
    ON p.productsubcategorykey = ps.productsubcategorykey
JOIN productcategory pc
    ON ps.productcategorykey = pc.productcategorykey
GROUP BY pc.categoryname
ORDER BY total_profit DESC;