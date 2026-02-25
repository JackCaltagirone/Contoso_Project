-- Count unique customers by country to identify major markets.
SELECT 
    c.countryfull AS country,
    COUNT(DISTINCT c.customerkey) AS customer_count
FROM customer c
GROUP BY c.countryfull
ORDER BY customer_count DESC;


-- Break down U.S. customers by state to find the strongest regions.
SELECT 
    c.statefull AS state,
    COUNT(DISTINCT c.customerkey) AS customer_count
FROM customer c
WHERE c.countryfull = 'United States'
GROUP BY c.statefull
ORDER BY customer_count DESC;


-- Compare category spending across the four largest states.
-- CTE: Hard‑code the top states for focused analysis.
WITH top_states AS (
    SELECT 'California' AS state
    UNION ALL SELECT 'Texas'
    UNION ALL SELECT 'Florida'
    UNION ALL SELECT 'New York'
)
SELECT
    c.statefull AS state,
    p.categoryname,
    SUM(s.quantity) AS total_items,
    SUM(s.netprice) AS total_revenue
FROM sales s
JOIN customer c ON s.customerkey = c.customerkey
JOIN product p ON s.productkey = p.productkey
JOIN top_states t ON c.statefull = t.state
GROUP BY c.statefull, p.categoryname
ORDER BY c.statefull, total_revenue DESC;


-- Cohort analysis for California.
-- CTE 1: Extract cohort year.
-- CTE 2: Assign cohort buckets.
-- CTE 3: Join sales + products.
-- CTE 4: Summarize revenue + profit.
-- CTE 5: Rank categories per cohort.
WITH cohorts AS (
    SELECT
        customerkey,
        statefull AS state,
        EXTRACT(YEAR FROM startdt) AS cohort_year
    FROM customer
    WHERE statefull = 'California'
),

cohort_buckets AS (
    SELECT
        c.customerkey,
        c.state,
        CASE
            WHEN cohort_year BETWEEN 1980 AND 1985 THEN '1980 - 1985'
            WHEN cohort_year BETWEEN 1986 AND 1990 THEN '1986 - 1990'
            WHEN cohort_year BETWEEN 1991 AND 1995 THEN '1991 - 1995'
            WHEN cohort_year BETWEEN 1996 AND 2000 THEN '1996 - 2000'
            WHEN cohort_year BETWEEN 2001 AND 2005 THEN '2001 - 2005'
            WHEN cohort_year BETWEEN 2006 AND 2010 THEN '2006 - 2010'
            WHEN cohort_year BETWEEN 2011 AND 2015 THEN '2011 - 2015'
            WHEN cohort_year BETWEEN 2016 AND 2020 THEN '2016 - 2020'
        END AS cohort_bucket
    FROM cohorts c
),

sales_enriched AS (
    SELECT
        cb.cohort_bucket,
        s.netprice,
        s.unitcost,
        p.categoryname
    FROM cohort_buckets cb
    JOIN sales s ON cb.customerkey = s.customerkey
    JOIN product p ON s.productkey = p.productkey
),

bucket_summary AS (
    SELECT
        cohort_bucket,
        SUM(netprice) AS total_revenue,
        SUM(netprice - unitcost) AS total_profit
    FROM sales_enriched
    GROUP BY cohort_bucket
),

top_category AS (
    SELECT
        cohort_bucket,
        categoryname,
        SUM(netprice) AS category_revenue,
        RANK() OVER (
            PARTITION BY cohort_bucket 
            ORDER BY SUM(netprice) DESC
        ) AS rnk
    FROM sales_enriched
    GROUP BY cohort_bucket, categoryname
)

SELECT
    bs.cohort_bucket,
    ROUND(bs.total_revenue::numeric, 2) AS revenue,
    ROUND(bs.total_profit::numeric, 2) AS profit,
    tc.categoryname AS top_category
FROM bucket_summary bs
JOIN top_category tc
    ON bs.cohort_bucket = tc.cohort_bucket
WHERE tc.rnk = 1
ORDER BY bs.cohort_bucket;


-- Cohort spend + items for California.
-- CTE 1: Extract cohort year.
-- CTE 2: Assign cohort buckets.
-- CTE 3: Join sales.
WITH cohorts AS (
    SELECT
        customerkey,
        statefull AS state,
        EXTRACT(YEAR FROM startdt) AS cohort_year
    FROM customer
    WHERE statefull = 'California'
),

cohort_buckets AS (
    SELECT
        c.customerkey,
        CASE
            WHEN cohort_year BETWEEN 1980 AND 1985 THEN '1980 - 1985'
            WHEN cohort_year BETWEEN 1986 AND 1990 THEN '1986 - 1990'
            WHEN cohort_year BETWEEN 1991 AND 1995 THEN '1991 - 1995'
            WHEN cohort_year BETWEEN 1996 AND 2000 THEN '1996 - 2000'
            WHEN cohort_year BETWEEN 2001 AND 2005 THEN '2001 - 2005'
            WHEN cohort_year BETWEEN 2006 AND 2010 THEN '2006 - 2010'
            WHEN cohort_year BETWEEN 2011 AND 2015 THEN '2011 - 2015'
            WHEN cohort_year BETWEEN 2016 AND 2020 THEN '2016 - 2020'
        END AS cohort_bucket
    FROM cohorts c
),

sales_enriched AS (
    SELECT
        cb.cohort_bucket,
        s.quantity,
        s.netprice,
        s.unitcost
    FROM cohort_buckets cb
    JOIN sales s ON cb.customerkey = s.customerkey
)

SELECT
    cohort_bucket,
    ROUND(SUM(netprice)::numeric, 2) AS total_revenue,
    SUM(quantity) AS total_items,
    ROUND(SUM(netprice - unitcost)::numeric, 2) AS total_profit
FROM sales_enriched
GROUP BY cohort_bucket
ORDER BY cohort_bucket;


-- Cohort spend + items across all states.
-- CTE 1: Extract cohort year.
-- CTE 2: Assign cohort buckets.
-- CTE 3: Join sales.
WITH cohorts AS (
    SELECT
        customerkey,
        statefull AS state,
        EXTRACT(YEAR FROM startdt) AS cohort_year
    FROM customer
),

cohort_buckets AS (
    SELECT
        customerkey,
        state,
        CASE
            WHEN cohort_year BETWEEN 1980 AND 1985 THEN '1980 - 1985'
            WHEN cohort_year BETWEEN 1986 AND 1990 THEN '1986 - 1990'
            WHEN cohort_year BETWEEN 1991 AND 1995 THEN '1991 - 1995'
            WHEN cohort_year BETWEEN 1996 AND 2000 THEN '1996 - 2000'
            WHEN cohort_year BETWEEN 2001 AND 2005 THEN '2001 - 2005'
            WHEN cohort_year BETWEEN 2006 AND 2010 THEN '2006 - 2010'
            WHEN cohort_year BETWEEN 2011 AND 2015 THEN '2011 - 2015'
            WHEN cohort_year BETWEEN 2016 AND 2020 THEN '2016 - 2020'
        END AS cohort_bucket
    FROM cohorts
),

sales_enriched AS (
    SELECT
        cb.state,
        cb.cohort_bucket,
        s.quantity,
        s.netprice
    FROM cohort_buckets cb
    JOIN sales s ON cb.customerkey = s.customerkey
)

SELECT
    state,
    cohort_bucket,
    ROUND(SUM(netprice)::numeric, 2) AS total_revenue,
    SUM(quantity) AS total_items
FROM sales_enriched
GROUP BY state, cohort_bucket
ORDER BY total_revenue DESC;