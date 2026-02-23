-- =====================================================================
-- Purpose:
-- Establish a baseline understanding of product-level financials.
-- We calculate revenue, cost, and profit at the order-line level so we
-- can validate data quality and confirm whether any transactions are
-- loss-making before moving into deeper analysis.
-- =====================================================================


-- Step 1:
-- Compute revenue, cost, and profit for each order line.
-- This is used to check for negative or zero-profit transactions.
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

-- No negative-profit rows found.
-- Next step: check the profit range to understand overall spread.


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
-- Since all rows are profitable, we classify each order line into
-- margin bands. This helps us understand the distribution of margins
-- across the dataset and verify whether any segments behave unusually.


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

-- All items fall into healthy margin ranges.
-- Since there are no low-margin or loss-making products, we pivot the
-- analysis toward understanding performance at the category level.


-- Pivot Step 1:
-- Aggregate revenue, cost, and profit by category.
-- This identifies which categories contribute most to overall financials.
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
    p.categoryname,
    COUNT(*) AS total_items,
    SUM(mb.revenue) AS total_revenue,
    SUM(mb.cost) AS total_cost,
    SUM(mb.profit) AS total_profit,
    AVG(mb.profit / mb.revenue) AS avg_margin
FROM margin_bands mb
JOIN product p
    ON mb.productkey = p.productkey
GROUP BY p.categoryname
ORDER BY total_profit DESC;

-- This gives us category-level profitability metrics for comparison.


-- Pivot Step 2:
-- Pull revenue-only metrics at the category level.
-- Used for visual comparison (e.g., revenue vs profit bar charts).
WITH order_revenue AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        ROUND((netprice::numeric * quantity), 2) AS revenue
    FROM sales
)

SELECT
    p.categoryname,
    COUNT(*) AS total_items,
    SUM(orv.revenue) AS total_revenue,
    AVG(orv.revenue) AS avg_revenue_per_item
FROM order_revenue orv
JOIN product p
    ON orv.productkey = p.productkey
GROUP BY p.categoryname
ORDER BY total_revenue DESC;

-- Category results show Computers as the top performer by a wide margin.
-- Next steps:
--   • Break Computers into subcategories to identify internal drivers.
--   • Analyze revenue and profit by country to determine geographic impact.