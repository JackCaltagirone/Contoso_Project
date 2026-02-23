-- =====================================================================
-- Purpose:
-- This file identifies where Contoso may be losing revenue by analyzing
-- product-level profitability. Using the sales, product, and store data,
-- we calculate revenue, cost, and profit for each order line to detect
-- low‑margin or negative‑margin transactions. These transactions represent
-- potential revenue leakage and operational inefficiencies.
-- =====================================================================



-- Step 1:
-- Calculate profit per order line by comparing revenue (netprice * quantity)
-- against cost (unitcost * quantity). Flag all orders where profit is zero
-- or negative, as these indicate direct financial loss.
-- =====================================================================