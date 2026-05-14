# 🧠 Customer Analytics Reporting System

> **A SQL-based Customer Intelligence & Business KPI Reporting system built on a dimensional data warehouse — transforming raw transactional data into churn signals, revenue insights, and customer segmentation.**

<img width="1672" height="941" alt="cover" src="https://github.com/user-attachments/assets/47c64333-08d0-4b15-a2ad-ea4c692c9f76" />

📺 **[Watch Full Project Walkthrough on YouTube →](https://www.youtube.com/watch?v=WygBwFUMQhg&t=1901s)**

---

## 📌 Project Overview

Most businesses sit on mountains of customer transaction data and still can't answer basic questions: *Who are our best customers? Who's about to leave? Which age group drives the most revenue?*

This project builds a **Customer Analytics Reporting System** using **Microsoft SQL Server** and **dimensional data warehouse** concepts to answer those questions — systematically, repeatably, and at scale.

The system is structured as a **4-layer SQL pipeline**:

```
Raw Data  →  Base Layer  →  Aggregation Layer  →  KPI Engineering  →  Reporting View
```

The final output is a single, reusable SQL view — `gold.cus_report` — that any BI tool, dashboard, or analyst can query directly for actionable insights.

---

## 🎯 Business Problems Solved

| # | Business Problem | SQL Solution | Impact |
|---|-----------------|--------------|--------|
| 1 | No visibility into high-value customers | Customer segmentation: VIP / Regular / New | Better loyalty programs, targeted retention |
| 2 | Customers churning undetected | Recency analysis using `DATEDIFF` | Early churn detection, win-back campaigns |
| 3 | One-time buyers never returning | Order frequency filter `WHERE total_orders = 1` | Improved onboarding & repeat purchase rate |
| 4 | Marketing spend not tied to demographics | Revenue by age group & geography | Better ROI, smarter ad targeting |
| 5 | No visibility into spending habits | AOV, monthly spend, CLV KPIs | Upselling & cross-selling opportunities |

---

## 🏗️ Data Warehouse Architecture

The project uses a **dimensional modeling** approach with two core tables feeding into a centralized reporting layer.

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   gold.dim_customers    │         │    gold.fact_sales      │
│  (Dimension Table)      │         │    (Fact Table)         │
│─────────────────────────│         │─────────────────────────│
│ customer_key            │◄───────►│ customer_key            │
│ customer_name           │         │ order_id                │
│ gender                  │         │ product_key             │
│ birthdate               │         │ order_date              │
│ country                 │         │ sales_amount            │
│ customer_number         │         │ quantity                │
└─────────────────────────┘         └─────────────────────────┘
              │                                  │
              └──────────────┬───────────────────┘
                             ▼
              ┌──────────────────────────┐
              │    gold.cus_report       │
              │  (Central Reporting View)│
              │──────────────────────────│
              │ Customer Demographics    │
              │ Purchasing Behavior      │
              │ Revenue Metrics          │
              │ Engagement KPIs          │
              │ Customer Segments        │
              └──────────────────────────┘
```

---

## ⚙️ SQL Workflow — 4-Layer Pipeline

### Layer 1 — Customer Base Layer
Join customer demographics with sales transactions to create the foundational dataset.

```sql
SELECT
    c.customer_key,
    c.customer_number,
    c.customer_name,
    c.gender,
    c.country,
    c.birthdate,
    DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age,
    f.order_date,
    f.sales_amount,
    f.quantity,
    f.product_key
FROM gold.dim_customers AS c
INNER JOIN gold.fact_sales AS f
    ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
```

---

### Layer 2 — Customer Aggregation Layer
Collapse individual transactions into per-customer summary metrics.

```sql
SELECT
    customer_key,
    customer_name,
    gender,
    country,
    age,
    MIN(order_date)                          AS first_order_date,
    MAX(order_date)                          AS last_order_date,
    COUNT(DISTINCT order_date)               AS total_orders,
    COUNT(DISTINCT product_key)              AS total_products,
    SUM(sales_amount)                        AS total_sales,
    SUM(quantity)                            AS total_quantity,
    DATEDIFF(MONTH, MIN(order_date),
             MAX(order_date))                AS lifespan_months
FROM base_layer
GROUP BY
    customer_key, customer_name, gender,
    country, age
```

---

### Layer 3 — KPI Engineering
Build advanced business metrics on top of the aggregated data.

```sql
SELECT
    *,
    -- Recency: months since last purchase
    DATEDIFF(MONTH, last_order_date, GETDATE())          AS recency_months,

    -- Average Order Value
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END                                                   AS avg_order_value,

    -- Average Monthly Spend
    CASE
        WHEN lifespan_months = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan_months, 2)
    END                                                   AS avg_monthly_spend

FROM aggregation_layer
```

---

### Layer 4 — Customer Segmentation
Classify every customer into a business-meaningful segment using CASE logic.

```sql
SELECT
    *,
    CASE
        WHEN total_sales > 5000
         AND lifespan_months >= 12   THEN 'VIP'
        WHEN lifespan_months >= 12   THEN 'Regular'
        ELSE                              'New'
    END AS customer_segment
FROM kpi_layer
```

**Segment Definitions:**

| Segment | Criteria | Business Action |
|---------|----------|-----------------|
| **VIP** | Sales > 5,000 AND active ≥ 12 months | Loyalty rewards, premium service |
| **Regular** | Active ≥ 12 months, lower spend | Upsell campaigns, engagement nudges |
| **New** | Active < 12 months | Onboarding, first-repeat incentives |

---

## 📊 KPIs Generated by the Reporting View

| KPI | Formula | Business Use |
|-----|---------|--------------|
| `total_sales` | `SUM(sales_amount)` | Customer revenue contribution |
| `total_orders` | `COUNT(DISTINCT order_date)` | Purchase frequency |
| `total_products` | `COUNT(DISTINCT product_key)` | Product diversity / breadth |
| `lifespan_months` | `DATEDIFF(MONTH, first_order, last_order)` | Customer relationship duration |
| `recency_months` | `DATEDIFF(MONTH, last_order, GETDATE())` | Churn risk indicator |
| `avg_order_value` | `total_sales / total_orders` | Revenue per transaction |
| `avg_monthly_spend` | `total_sales / lifespan_months` | Recurring revenue value |
| `customer_segment` | CASE logic on sales + lifespan | Segmentation for targeting |

---

## 💡 Business Use Cases Enabled

```
Customer Retention        →  Identify and re-engage at-risk customers before churn
Churn Prediction          →  Flag customers with high recency_months for win-back
Loyalty Program Targeting →  Prioritize VIP segment for premium engagement
Marketing Optimization    →  Target campaigns by age group, country, segment
Revenue Intelligence      →  Understand which demographics drive the most value
CLV Analysis              →  Forecast long-term revenue per customer
Engagement Tracking       →  Identify one-time buyers for onboarding campaigns
Geographic Analysis       →  Analyze regional sales performance differences
```

---

## 🔧 SQL Techniques Used

| Technique | Applied In |
|-----------|-----------|
| `CTEs (WITH clause)` | Multi-layer pipeline construction (base → aggregation → KPI → segment) |
| `INNER JOIN` | Linking `dim_customers` with `fact_sales` on `customer_key` |
| `DATEDIFF()` | Recency calculation, lifespan computation, age calculation |
| `CASE Statements` | Customer segmentation logic (VIP / Regular / New) |
| `Conditional Aggregation` | Churn flagging, low-engagement filtering |
| `Window Aggregations` | `MIN()` / `MAX()` for first/last order date tracking |
| `SQL VIEW` | Reusable `gold.cus_report` reporting layer |
| `GROUP BY` | Per-customer metric rollups by demographics and geography |
| `NULLIF / CASE guards` | Preventing division-by-zero in AOV and monthly spend KPIs |

---

## 📁 Project Structure

```
customer-analytics-data-warehouse/
│
├── sql/
│   ├── 01_base_layer.sql              # Customer + sales join
│   ├── 02_aggregation_layer.sql       # Per-customer metric rollup
│   ├── 03_kpi_engineering.sql         # AOV, monthly spend, recency
│   ├── 04_segmentation_layer.sql      # VIP / Regular / New logic
│   └── 05_reporting_view.sql          # Final gold.cus_report VIEW
│
├── architecture/
│   └── data_warehouse_diagram.png     # Fact-dimension architecture diagram
│
├── screenshots/
│   ├── segmentation_output.png
│   ├── kpi_results.png
│   └── churn_detection_output.png
│
└── README.md
```

---

## ⚙️ Setup & Usage

### Prerequisites
- Microsoft SQL Server (Express or Developer Edition)
- SQL Server Management Studio (SSMS)
- A database with `gold.dim_customers` and `gold.fact_sales` tables populated

### Steps to Run

**1. Clone the repository**
```bash
git clone https://github.com/yourusername/customer-analytics-data-warehouse.git
```

**2. Execute scripts in order**
```sql
-- Run in SSMS in this sequence:
-- Step 1: Base layer
EXEC sql/01_base_layer.sql

-- Step 2: Aggregation
EXEC sql/02_aggregation_layer.sql

-- Step 3: KPI engineering
EXEC sql/03_kpi_engineering.sql

-- Step 4: Segmentation
EXEC sql/04_segmentation_layer.sql

-- Step 5: Create reporting view
EXEC sql/05_reporting_view.sql
```

**3. Query the reporting view**
```sql
-- Full customer intelligence report
SELECT * FROM gold.cus_report;

-- VIP customers only
SELECT * FROM gold.cus_report
WHERE customer_segment = 'VIP'
ORDER BY total_sales DESC;

-- At-risk churn customers (inactive 6+ months)
SELECT customer_name, recency_months, total_sales
FROM gold.cus_report
WHERE recency_months >= 6
ORDER BY total_sales DESC;

-- Revenue by country
SELECT country, SUM(total_sales) AS regional_revenue
FROM gold.cus_report
GROUP BY country
ORDER BY regional_revenue DESC;
```

---

## 📺 Project Walkthrough

**Full explanation of the project architecture, SQL workflow, and business insights:**

🎬 **[Watch on YouTube →](https://www.youtube.com/watch?v=WygBwFUMQhg&t=1901s)**

The video covers:
- Data warehouse architecture explained
- Step-by-step SQL pipeline walkthrough
- Customer segmentation logic deep-dive
- KPI engineering breakdown
- Live query demonstrations on `gold.cus_report`

---

## 🚀 Business Impact Summary

| Business Goal | How This Project Addresses It |
|---------------|-------------------------------|
| Reduce churn | `recency_months` flags at-risk customers before they leave |
| Improve retention | VIP segment identified for priority engagement |
| Optimize marketing | Demographic + geographic revenue breakdown guides ad spend |
| Increase CLV | AOV and monthly spend KPIs surface upselling opportunities |
| Scale analytics | Single reusable view replaces fragmented ad-hoc queries |

---

## 🔮 Future Enhancements

- **Power BI Dashboard** — Visual layer on top of `gold.cus_report`
- **RFM Segmentation** — Recency + Frequency + Monetary scoring model
- **Predictive Churn Modeling** — ML layer using Python + SQL Server
- **Automated ETL Pipelines** — Scheduled data refresh with SQL Agent Jobs
- **Cohort Analysis** — Month-by-month retention cohort tracking
- **Customer Scoring Models** — Numeric health score per customer

---

## 🛠️ Tools & Environment

![SQL Server](https://img.shields.io/badge/Microsoft_SQL_Server-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![SSMS](https://img.shields.io/badge/SSMS-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-4479A1?style=for-the-badge&logo=databricks&logoColor=white)

- **Database:** Microsoft SQL Server (Express/Developer)
- **IDE:** SQL Server Management Studio (SSMS)
- **Language:** T-SQL
- **Architecture:** Dimensional Data Warehouse (Fact + Dimension)
- **Modeling:** Gold layer schema with reusable reporting view

---

## 👤 Author

**Sandip** — Data Analyst
📍 Nagpur, Maharashtra, India
🔗 [LinkedIn](https://linkedin.com/in/sandipmandal52/) | [GitHub](https://github.com/SandipMandal-52) | [YouTube](https://www.youtube.com/@datawithsandip)

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

*If this project helped you, consider giving it a ⭐ on GitHub.*
