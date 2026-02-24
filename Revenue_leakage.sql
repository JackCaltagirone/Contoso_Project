-- =====================================================================
-- Purpose:
-- Build a financial baseline by calculating revenue, cost, and profit
-- at the order-line level. This validates data quality before deeper
-- category, subcategory, and country analysis.
-- =====================================================================


-- Check whether any transactions lose money.
-- CTE: Computes revenue, cost, and profit for each order line.
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
        ROUND((netprice::numeric * quantity - unitcost::numeric * quantity), 2) AS profit
    FROM sales
)
SELECT *
FROM order_profit
WHERE profit <= 0
LIMIT 10;


-- Inspect the overall profit range to confirm dataset health.
-- CTE: Recomputes profit to check min/max values.
WITH order_profit AS (
    SELECT
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND((netprice::numeric * quantity - unitcost::numeric * quantity), 2) AS profit
    FROM sales
)
SELECT
    MIN(profit) AS min_profit,
    MAX(profit) AS max_profit
FROM order_profit;


-- Classify each order into margin bands to understand profitability distribution.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Assign each row to a margin band.
WITH order_profit AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND((netprice::numeric * quantity - unitcost::numeric * quantity), 2) AS profit
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
            WHEN profit / revenue < 0.25 THEN '< 25%'
            WHEN profit / revenue BETWEEN 0.25 AND 0.35 THEN '25% - 35%'
            WHEN profit / revenue BETWEEN 0.35 AND 0.45 THEN '35% - 45%'
            WHEN profit / revenue BETWEEN 0.45 AND 0.55 THEN '45% - 55%'
            WHEN profit / revenue BETWEEN 0.55 AND 0.65 THEN '55% - 65%'
            WHEN profit / revenue BETWEEN 0.65 AND 0.75 THEN '65% - 75%'
            WHEN profit / revenue > 0.75 THEN '> 75%'
        END AS margin_band
    FROM order_profit
)
SELECT
    margin_band,
    COUNT(*) AS item_count
FROM margin_bands
GROUP BY margin_band
ORDER BY margin_band;


-- Evaluate profitability at the category level.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Add margin bands for consistency.
WITH order_profit AS (
    SELECT
        orderkey,
        productkey,
        quantity,
        ROUND((netprice::numeric * quantity), 2) AS revenue,
        ROUND((unitcost::numeric * quantity), 2) AS cost,
        ROUND((netprice::numeric * quantity - unitcost::numeric * quantity), 2) AS profit
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
            WHEN profit / revenue < 0.25 THEN '< 25%'
            WHEN profit / revenue BETWEEN 0.25 AND 0.35 THEN '25% - 35%'
            WHEN profit / revenue BETWEEN 0.35 AND 0.45 THEN '35% - 45%'
            WHEN profit / revenue BETWEEN 0.45 AND 0.55 THEN '45% - 55%'
            WHEN profit / revenue BETWEEN 0.55 AND 0.65 THEN '55% - 65%'
            WHEN profit / revenue BETWEEN 0.65 AND 0.75 THEN '65% - 75%'
            WHEN profit / revenue > 0.75 THEN '> 75%'
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


-- Provide a revenue-only view of categories for visual comparison.
-- CTE: Computes revenue per order line.
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


-- Drill into subcategories within the Computers category.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Filter product hierarchy to Computers only.
WITH order_profit AS (
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue,
        ROUND((s.unitcost::numeric * s.quantity), 2) AS cost,
        ROUND((s.netprice::numeric * s.quantity - s.unitcost::numeric * s.quantity), 2) AS profit
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


-- Provide a revenue-only view of subcategories.
-- CTE: Computes revenue per order line.
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


-- Break Desktop performance down by country.
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
        ROUND((s.netprice::numeric * s.quantity - s.unitcost::numeric * s.quantity), 2) AS profit
    FROM sales s
),

product_hierarchy AS (
    SELECT
        p.productkey
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


-- Since the United States dominates Desktop sales, analyze WHEN those sales occur.
-- CTE 1: Compute revenue, cost, profit.
-- CTE 2: Filter to Desktop products.
-- CTE 3: Filter to US customers.
-- CTE 4: Bring in date attributes for time-series analysis.
WITH order_profit AS (
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        s.customerkey,
        s.orderdate,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue,
        ROUND((s.unitcost::numeric * s.quantity), 2) AS cost,
        ROUND((s.netprice::numeric * s.quantity - s.unitcost::numeric * s.quantity), 2) AS profit
    FROM sales s
),

product_hierarchy AS (
    SELECT
        p.productkey
    FROM product p
    WHERE p.categoryname = 'Computers'
      AND p.subcategoryname = 'Desktops'
),

customer_us AS (
    SELECT
        c.customerkey
    FROM customer c
    WHERE c.countryfull = 'United States'
),

date_dim AS (
    SELECT
        d.date,
        d.year,
        d.yearmonth,
        d.yearmonthshort,
        d.month,
        d.monthshort
    FROM date d
)
SELECT
    dd.year,
    dd.yearmonthshort AS month,
    SUM(op.revenue) AS total_revenue,
    SUM(op.cost) AS total_cost,
    SUM(op.profit) AS total_profit,
    AVG(op.profit / op.revenue) AS avg_margin
FROM order_profit op
JOIN product_hierarchy ph
    ON op.productkey = ph.productkey
JOIN customer_us cu
    ON op.customerkey = cu.customerkey
JOIN date_dim dd
    ON op.orderdate = dd.date
GROUP BY dd.year, dd.yearmonthshort
ORDER BY total_profit DESC;
-- Evaluate overall seasonality for US Desktop sales by aggregating all years
-- into a single month-level view. This shows which months (1–12) generate the
-- highest total revenue and profit.
-- CTE 1: Compute revenue, cost, and profit.
-- CTE 2: Filter to Desktop products.
-- CTE 3: Restrict to US customers.
-- CTE 4: Bring in month attributes only (no year).

WITH order_profit AS (
    -- Compute revenue, cost, and profit per order line
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        s.customerkey,
        s.orderdate,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue,
        ROUND((s.unitcost::numeric * s.quantity), 2) AS cost,
        ROUND((s.netprice::numeric * s.quantity - s.unitcost::numeric * s.quantity), 2) AS profit
    FROM sales s
),

product_hierarchy AS (
    -- Filter to Computers → Desktops
    SELECT
        p.productkey
    FROM product p
    WHERE p.categoryname = 'Computers'
      AND p.subcategoryname = 'Desktops'
),

customer_us AS (
    -- Restrict to US customers only
    SELECT
        c.customerkey
    FROM customer c
    WHERE c.countryfull = 'United States'
),

date_dim AS (
    -- Extract month number (1–12) for seasonality analysis
    SELECT
        d.date,
        d.month
    FROM date d
)

SELECT
    dd.month AS month_number,
    SUM(op.revenue) AS total_revenue,
    SUM(op.profit) AS total_profit,
    RANK() OVER (ORDER BY SUM(op.profit) DESC) AS profit_rank
FROM order_profit op
JOIN product_hierarchy ph
    ON op.productkey = ph.productkey
JOIN customer_us cu
    ON op.customerkey = cu.customerkey
JOIN date_dim dd
    ON op.orderdate = dd.date
GROUP BY dd.month
ORDER BY total_profit DESC;

-- Build a month-by-year matrix of total profit for US Desktop sales.
-- This output is heatmap-ready: rows = months, columns = years.
-- CTE 1: Compute revenue, cost, and profit.
-- CTE 2: Filter to Desktop products.
-- CTE 3: Restrict to US customers.
-- CTE 4: Bring in year + month attributes.
-- Final: Pivot into a month × year matrix.

WITH order_profit AS (
    SELECT
        s.orderkey,
        s.productkey,
        s.quantity,
        s.customerkey,
        s.orderdate,
        ROUND((s.netprice::numeric * s.quantity), 2) AS revenue,
        ROUND((s.unitcost::numeric * s.quantity), 2) AS cost,
        ROUND((s.netprice::numeric * s.quantity - s.unitcost::numeric * s.quantity), 2) AS profit
    FROM sales s
),

product_hierarchy AS (
    SELECT
        p.productkey
    FROM product p
    WHERE p.categoryname = 'Computers'
      AND p.subcategoryname = 'Desktops'
),

customer_us AS (
    SELECT
        c.customerkey
    FROM customer c
    WHERE c.countryfull = 'United States'
),

date_dim AS (
    SELECT
        d.date,
        d.year,
        d.month,
        d.monthshort
    FROM date d
),

base AS (
    SELECT
        dd.year,
        dd.month,
        dd.monthshort,
        op.profit
    FROM order_profit op
    JOIN product_hierarchy ph ON op.productkey = ph.productkey
    JOIN customer_us cu ON op.customerkey = cu.customerkey
    JOIN date_dim dd ON op.orderdate = dd.date
)

SELECT
    monthshort AS month,
    SUM(CASE WHEN year = 2016 THEN profit END) AS y2016,
    SUM(CASE WHEN year = 2017 THEN profit END) AS y2017,
    SUM(CASE WHEN year = 2018 THEN profit END) AS y2018,
    SUM(CASE WHEN year = 2019 THEN profit END) AS y2019,
    SUM(CASE WHEN year = 2020 THEN profit END) AS y2020,
    SUM(CASE WHEN year = 2021 THEN profit END) AS y2021,
    SUM(CASE WHEN year = 2022 THEN profit END) AS y2022,
    SUM(CASE WHEN year = 2023 THEN profit END) AS y2023
FROM base
GROUP BY month, monthshort
ORDER BY month;