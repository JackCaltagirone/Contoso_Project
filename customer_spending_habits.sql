/* =====================================================================
 SECTION — CUSTOMER DISTRIBUTION BY COUNTRY
 PURPOSE:
 Count unique customers per country to understand the geographic
 spread of the customer base and identify high‑population markets.
 DEPENDS ON:
 - customer_dim (customer → country mapping)
 ===================================================================== */


-- Query to count unique customers by country
SELECT c.countryfull AS country,
  COUNT(DISTINCT c.customerkey) AS customer_count
FROM customer c
GROUP BY c.countryfull
ORDER BY customer_count DESC;


-- after finding the US as the top country were going to deep dive into it and see
-- we can find
SELECT c.statefull AS state,
  COUNT(DISTINCT c.customerkey) AS customer_count
FROM customer c
WHERE c.countryfull = 'United States'
GROUP BY c.statefull
ORDER BY customer_count DESC;


-- with this we see the four being california, texas, florida and new york
-- going to see what these four have in common or what these states are buying
-- that other states are not. 


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

-- it would seem all 4 states have the exact same categorry spending
--lets change perspective and see if a customer cohort base in each state
--state changes year by year

WITH cohorts AS (
    SELECT
        customerkey,
        statefull AS state,
        EXTRACT(YEAR FROM startdt) AS cohort_year
    FROM customer
    WHERE statefull IN ('California','Texas','Florida','New York')
),
cohort_spend AS (
    SELECT
        c.state,
        c.cohort_year,
        d.year AS sales_year,
        SUM(s.netprice) AS revenue
    FROM cohorts c
    JOIN sales s ON c.customerkey = s.customerkey
    JOIN date d ON s.orderdate = d.date
    GROUP BY c.state, c.cohort_year, d.year
)
SELECT
    state,
    cohort_year,
    sales_year,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        revenue - LAG(revenue) OVER (
            PARTITION BY state, cohort_year
            ORDER BY sales_year
        ), 
    2) AS yoy_change
FROM cohort_spend
ORDER BY state, cohort_year, sales_year;