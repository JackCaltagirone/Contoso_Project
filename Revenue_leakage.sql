-- =====================================================================
-- Purpose:
-- Build a financial baseline by calculating revenue, cost, and profit
-- at the order-line level. This validates data quality before deeper
-- category, subcategory, and country analysis.
-- =====================================================================


-- Step 1: Check for negative or zero-profit transactions.
-- CTE: Calculates revenue, cost, and profit per order line.
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


-- Step 1b: Check overall profit range.
-- CTE: Recomputes profit to inspect min/max values.
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


-- Step 2: Classify each order into margin bands.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Assign each row to a margin band.
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


-- Step 3: Category-level profitability.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Add margin bands for consistency.
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


-- Step 4: Revenue-only category view.
-- CTE: Compute revenue per order line.
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


-- Step 5: Subcategory-level profitability (Computers only).
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Filter product hierarchy to Computers.
WITH order_profit AS (
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue,
        ROUND((s.unitcost::numeric * s.quantity), 2) AS cost,
        ROUND(((s.netprice::numeric * s.quantity) - (s.unitcost::numeric * s.quantity)), 2) AS profit
    FROM sales s
),

product_hierarchy AS (
    SELECT
        p.productkey,
        p.subcategoryname,
        p.categoryname
    FROM product p
    WHERE p.categoryname = 'Computers'
)

SELECT
    ph.subcategoryname,
    COUNT(*) AS total_items,
    SUM(op.revenue) AS total_revenue,
    SUM(op.cost) AS total_cost,
    SUM(op.profit) AS total_profit,
    AVG(op.profit / op.revenue) AS avg_margin
FROM order_profit op
JOIN product_hierarchy ph
    ON op.productkey = ph.productkey
GROUP BY ph.subcategoryname
ORDER BY total_profit DESC;


-- Step 6: Revenue-only subcategory view.
-- CTE: Compute revenue per order line.
WITH order_revenue AS (
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue
    FROM sales s
),

product_hierarchy AS (
    SELECT
        p.productkey,
        p.subcategoryname,
        p.categoryname
    FROM product p
    WHERE p.categoryname = 'Computers'
)

SELECT
    ph.subcategoryname,
    COUNT(*) AS total_items,
    SUM(orv.revenue) AS total_revenue,
    AVG(orv.revenue) AS avg_revenue_per_item
FROM order_revenue orv
JOIN product_hierarchy ph
    ON orv.productkey = ph.productkey
GROUP BY ph.subcategoryname
ORDER BY total_revenue DESC;


-- Step 7: Desktop performance by country.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Filter to Desktop products.
-- CTE 3: Bring in customer country.
WITH order_profit AS (
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        s.customerkey,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue,
        ROUND((s.unitcost::numeric * s.quantity), 2) AS cost,
        ROUND(((s.netprice::numeric * s.quantity) - (s.unitcost::numeric * s.quantity)), 2) AS profit
    FROM sales s
),

product_hierarchy AS (
    SELECT
        p.productkey,
        p.subcategoryname,
        p.categoryname
    FROM product p
    WHERE p.categoryname = 'Computers'
      AND p.subcategoryname = 'Desktops'
),

customer_dim AS (
    SELECT
        c.customerkey,
        c.countryfull
    FROM customer c
)

SELECT
    cd.countryfull AS country,
    COUNT(*) AS total_items,
    SUM(op.revenue) AS total_revenue,
    SUM(op.cost) AS total_cost,
    SUM(op.profit) AS total_profit,
    AVG(op.profit / op.revenue) AS avg_margin
FROM order_profit op
JOIN product_hierarchy ph
    ON op.productkey = ph.productkey
JOIN customer_dim cd
    ON op.customerkey = cd.customerkey
GROUP BY cd.countryfull
ORDER BY total_profit DESC;