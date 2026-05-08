USE DataWerehouseAnalytics;
GO

/* ==========================================================================================
   CUSTOMER REPORT VIEW
   ==========================================================================================

   PURPOSE:

   Consolidates customer demographics, purchasing behavior, and business KPIs
   into a reusable reporting layer for analytics and dashboarding.

   METRICS INCLUDED:
   - Customer segmentation (VIP / Regular / New)
   - Age segmentation
   - Total sales, quantity, products, and orders
   - Customer lifespan
   - Recency
   - Average order value
   - Average monthly spend
========================================================================================== */


CREATE OR ALTER VIEW gold.cus_report AS

/* ------------------------------------------------------------------------------------------
   STEP 1: Base customer transaction dataset
   - Combines customer and sales information
   - Keeps only valid transactions
-------------------------------------------------------------------------------------------*/
WITH customer_base AS
(
    SELECT
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.country,
        c.gender,

        -- Approximate age calculation
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age,

        f.order_date,
        f.product_key,
        f.sales_amount,
        f.quantity,
        f.order_number

    FROM gold.dim_customers AS c
    INNER JOIN gold.fact_sales AS f
        ON c.customer_key = f.customer_key

    WHERE f.order_date IS NOT NULL
),

/* ------------------------------------------------------------------------------------------
   STEP 2: Aggregate customer-level metrics
-------------------------------------------------------------------------------------------*/
customer_aggregation AS
(
    SELECT
        customer_key,
        customer_number,
        customer_name,
        country,
        gender,
        age,

        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,

        COUNT(DISTINCT product_key) AS total_products,
        COUNT(DISTINCT order_number) AS total_orders,

        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,

        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months

    FROM customer_base

    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        country,
        gender,
        age
)

/* ------------------------------------------------------------------------------------------
   STEP 3: Final business-ready report
-------------------------------------------------------------------------------------------*/
SELECT
    customer_key,
    customer_number,
    customer_name,
    country,
    gender,
    age,

    /* Customer Segmentation */
    CASE
        WHEN total_sales > 5000
             AND lifespan_months >= 12
            THEN 'VIP'

        WHEN total_sales BETWEEN 3000 AND 5000
             AND lifespan_months >= 12
            THEN 'Regular'

        ELSE 'New Customer'
    END AS customer_type,

    /* Age Segmentation */
    CASE
        WHEN age >= 50 THEN '50 & Above'
        WHEN age >= 30 THEN '30 to 49'
        WHEN age >= 20 THEN '20 to 29'
        WHEN age >= 10 THEN '10 to 19'
        ELSE 'Not Specified'
    END AS age_group,

    total_sales,
    total_quantity,
    total_products,
    total_orders,

    first_order_date,
    last_order_date,

    lifespan_months,

    /* KPI: Months since last purchase */
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency_months,

    /* KPI: Average revenue per order */
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(CAST(total_sales AS Float) / total_orders,2)
    END AS avg_order_value,

    /* KPI: Average monthly spend */
    CASE
        WHEN lifespan_months = 0 THEN total_sales
        ELSE ROUND(CAST(total_sales AS float)/ lifespan_months,2)
    END AS avg_monthly_spend

FROM customer_aggregation;
GO

/* -- ********************************************************************************** --

                  BUSINESS PROBLEM AND IMPACT

-- ********************************************************************************** -- */


-- 1. Identify High-Value Customers (VIP Customers)     ---------------------------------------

-- #1 Business Problem
--      The company does not know which customers generate the highest long-term revenue.

SELECT TOP 50
    CUSTOMER_KEY,
    CUSTOMER_NAME,
    country,
    TOTAL_SALES
FROM gold.cus_report
WHERE customer_type = 'VIP'
ORDER BY total_sales DESC;



/*  Solution

Create VIP loyalty programs:
    exclusive discounts
    premium support
    early product access

📍Business Impact
    Improves retention of top customers
    Increases repeat purchases
    Maximizes customer lifetime value (CLV)  */

/* =====================================================================================

            2. Detect Customer Churn Risk

 #2 Business Problem:
    Customers stop purchasing, but the business notices too late. */

    SELECT *
    FROM gold.cus_report
    WHERE recency_months >= 6
    ORDER BY recency_months DESC;

/* -------------------------------------------------------------------------------------------------

                       -------:   Solution  :----

Launch win-back campaigns:
    reminder emails
    discount offers
    personalized recommendations

📍Business Impact
    Reduces customer churn
    Recovers lost revenue
    Improves customer retention 

===========================================================================================

            3.Find Customers with Low Engagement

 # Business Problem:
    Some customers place only one order and never return. */

    SELECT *
    FROM gold.cus_report
    WHERE total_orders = 1;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

Target these customers with:
    onboarding campaigns
    first-repeat purchase discounts
    educational content

📍Business Impact
    Converts one-time buyers into repeat customers
    Improves retention rate
    Increases order frequency

===========================================================================================

            4. Analyze Revenue by Age Group

 # Business Problem:
    Marketing does not know which age groups generate the most revenue. */

    SELECT
        age_group,
        SUM(total_sales) AS revenue
    FROM gold.cus_report
    GROUP BY age_group
    ORDER BY revenue DESC;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

  Focus advertising spend on the highest-performing age segments.

📍Business Impact
    Better marketing ROI
    More effective targeting
    Increased campaign conversion rates

===============================================================================================
            
            5. Identify Customers with High Order Frequency

 # Business Problem:
    The business cannot identify highly active customers. */

    SELECT TOP 20
        customer_name,
        total_orders
    FROM gold.cus_report
    ORDER BY total_orders DESC;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

Target these customers with:
    onboarding campaigns
    first-repeat purchase discounts
    educational content

📍Business Impact
    Converts one-time buyers into repeat customers
    Improves retention rate
    Increases order frequency

===============================================================================================
            
            6. Measure Average Customer Spending Behavior

 # Business Problem:
    The company does not know how much customers spend per transaction. */

    SELECT
        customer_name,
        avg_order_value
    FROM gold.cus_report
    ORDER BY avg_order_value DESC;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

 Create upselling and cross-selling strategies

📍Business Impact
    Increases basket size
    Improves sales efficiency
    Boosts overall revenue


===============================================================================================
            
            7. Discover Underperforming Geographic Regions

 # Business Problem:
    Some countries or regions may have weak sales performance. */

    SELECT
        country,
        SUM(total_sales) AS revenue
    FROM gold.cus_report
    GROUP BY country
    ORDER BY revenue ASC;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

 Investigate:
    local competition
    pricing issues
    marketing gaps

📍Business Impact
    Improves regional sales strategy
    Expands market opportunities
    Optimizes resource allocation

===============================================================================================
            
              8. Segment Customers Based on Spending Patterns

 # Business Problem:
    Marketing campaigns are too broad and ineffective. */
    
    SELECT
        customer_type,
        COUNT(*) AS total_customers,
        AVG(total_sales) AS avg_sales
    FROM gold.cus_report
    GROUP BY customer_type;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

Run separate campaigns for:
    VIP customers
    Regular customers
    New customers

📍Business Impact
    Personalized customer experience
    Better conversion rates
    Higher customer satisfaction


===============================================================================================
            
              9. Identify Customers with Declining Activity

 # Business Problem:
    Some customers gradually reduce purchases before churning. */

    SELECT *
    FROM gold.cus_report
    WHERE avg_monthly_spend < 100
     AND recency_months >= 6;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

 Create proactive retention campaigns before customers leave.

📍Business Impact
    Early churn prevention
    Maintains stable revenue
    Improves customer relationships

===============================================================================================
            
                10. Evaluate Long-Term Customer Value

 # Business Problem:
    The business does not know which customers are profitable over time. */

    SELECT TOP 50
        customer_name,
        lifespan_months,
        total_sales,
        avg_monthly_spend
    FROM gold.cus_report
    ORDER BY total_sales DESC;

/* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

 Use customer lifetime metrics for:
    acquisition budgeting
    retention planning
    loyalty investment.

📍Business Impact
    /* -------------------------------------------------------------------------------------------------
                       -------:   Solution  :----

 Create proactive retention campaigns before customers leave.

📍Business Impact
    Better strategic decisions
    Smarter marketing investments
    Improved profitability

