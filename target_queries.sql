/* =====================================================================
   TARGET BRAZIL E-COMMERCE SQL ANALYTICS
   Author : Praveen M C
   Platform : Google BigQuery
   ===================================================================== */


/* =====================================================================
   SECTION 1 : EXPLORATORY ANALYSIS
   ===================================================================== */

-- Q1. Data types of all columns in customers table

SELECT
    column_name,
    data_type
FROM project-id.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'customers';


-- Q2. Time range between which orders were placed

SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM target.orders;


-- Q3. Number of unique cities and states

SELECT
    COUNT(DISTINCT customer_city) AS no_of_city,
    COUNT(DISTINCT customer_state) AS no_of_state
FROM target.customers;


/* =====================================================================
   SECTION 2 : IN-DEPTH EXPLORATION
   ===================================================================== */

-- Q4. Year-wise order trend

SELECT
    COUNT(order_id) AS number_of_orders,
    EXTRACT(YEAR FROM order_purchase_timestamp) AS year
FROM target.orders
GROUP BY year
ORDER BY year DESC;


-- Q5. Monthly seasonality analysis

SELECT
    COUNT(order_id) AS number_of_orders,
    EXTRACT(MONTH FROM order_purchase_timestamp) AS month,
    EXTRACT(YEAR FROM order_purchase_timestamp) AS year
FROM target.orders
GROUP BY month, year
ORDER BY month, year;


-- Q6. Orders by time of day

SELECT
    COUNT(order_id) AS number_of_orders,
    CASE
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 0 AND 6
            THEN 'Dawn'
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 7 AND 12
            THEN 'Morning'
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 13 AND 18
            THEN 'Afternoon'
        ELSE 'Night'
    END AS purchase_period
FROM target.orders
GROUP BY purchase_period
ORDER BY number_of_orders;


/* =====================================================================
   SECTION 3 : EVOLUTION OF E-COMMERCE ORDERS
   ===================================================================== */

-- Q7. Month-on-month orders by state

SELECT
    state,
    month,
    year,
    SUM(no_of_orders) AS total_orders
FROM
(
    SELECT
        c.customer_state AS state,
        EXTRACT(MONTH FROM o.order_delivered_customer_date) AS month,
        EXTRACT(YEAR FROM o.order_delivered_customer_date) AS year,
        COUNT(o.order_id) OVER
        (
            PARTITION BY
            EXTRACT(MONTH FROM o.order_delivered_customer_date),
            c.customer_state
        ) AS no_of_orders
    FROM target.orders o
    JOIN target.customers c
        ON o.customer_id = c.customer_id
    WHERE EXTRACT(YEAR FROM o.order_delivered_customer_date)
          IN (2016,2017,2018)
)
GROUP BY state, month, year
ORDER BY month;


-- Q8. Customer distribution by state

SELECT
    customer_state,
    COUNT(customer_id) AS number_of_customers
FROM target.customers
GROUP BY customer_state
ORDER BY number_of_customers DESC,
         customer_state;


/* =====================================================================
   SECTION 4 : IMPACT ON ECONOMY
   ===================================================================== */

-- Q9. Percentage increase in order cost (2017 vs 2018)

SELECT
ROUND(
      (
        MAX(total_cost) - MIN(total_cost)
      )
      /
      MIN(total_cost)
      * 100
      ,2
) AS cost_pct_increase
FROM
(
    SELECT DISTINCT
        EXTRACT(YEAR FROM o.order_delivered_customer_date) AS year,
        SUM(payment_value) OVER
        (
            ORDER BY
            EXTRACT(YEAR FROM o.order_delivered_customer_date)
        ) AS total_cost
    FROM target.payments p
    JOIN target.orders o
        ON o.order_id = p.order_id
    WHERE EXTRACT(MONTH FROM o.order_delivered_customer_date)
          BETWEEN 1 AND 8
      AND EXTRACT(YEAR FROM o.order_delivered_customer_date)
          IN (2017,2018)
);


-- Q10. Total and average order price by state

SELECT DISTINCT
    customer_state,
    ROUND(
        SUM(total_price)
        OVER(PARTITION BY customer_state),2
    ) AS total_price,

    ROUND(
        AVG(total_price)
        OVER(PARTITION BY customer_state),2
    ) AS avg_total_price
FROM
(
    SELECT DISTINCT
        c.customer_state,
        SUM(oi.price)
            OVER(PARTITION BY c.customer_state)
            AS total_price,
        AVG(oi.price) AS avg_price,
        EXTRACT(YEAR FROM oi.shipping_limit_date) AS year
    FROM target.order_items oi
    JOIN target.orders o
        ON oi.order_id = o.order_id
    JOIN target.customers c
        ON o.customer_id = c.customer_id
    GROUP BY
        customer_state,
        price,
        EXTRACT(YEAR FROM shipping_limit_date),
        shipping_limit_date
)
ORDER BY avg_total_price,
         customer_state;


/* =====================================================================
   SECTION 5 : FREIGHT ANALYSIS
   ===================================================================== */

-- Q11. Total and average freight value by state

SELECT DISTINCT
    customer_state,

    ROUND(
        SUM(total_freight_value)
        OVER(PARTITION BY customer_state),2
    ) AS total_freight_value,

    ROUND(
        AVG(total_freight_value)
        OVER(PARTITION BY customer_state),2
    ) AS avg_total_freight_value

FROM
(
    SELECT DISTINCT
        c.customer_state,

        SUM(oi.freight_value)
        OVER(PARTITION BY c.customer_state)
        AS total_freight_value,

        AVG(freight_value)
        AS avg_freight_value,

        EXTRACT(YEAR FROM shipping_limit_date) AS year

    FROM target.order_items oi
    JOIN target.orders o
        ON oi.order_id = o.order_id
    JOIN target.customers c
        ON o.customer_id = c.customer_id

    GROUP BY
        customer_state,
        freight_value,
        EXTRACT(YEAR FROM shipping_limit_date),
        shipping_limit_date
)
ORDER BY avg_total_freight_value,
         customer_state;


/* =====================================================================
   SECTION 6 : DELIVERY PERFORMANCE
   ===================================================================== */

-- Q12. Delivery time and estimated vs actual difference

SELECT
    order_id,

    DATE_DIFF(
        order_delivered_customer_date,
        order_purchase_timestamp,
        DAY
    ) AS time_to_deliver,

    DATE_DIFF(
        order_estimated_delivery_date,
        order_delivered_customer_date,
        DAY
    ) AS diff_estimated_delivery

FROM target.orders;


-- Q13. Top 5 states with highest average freight value

SELECT
    customer_state,

    ROUND(
        AVG(freight_value),
        2
    ) AS avg_freight_value

FROM target.order_items oi
JOIN target.orders o
    ON oi.order_id = o.order_id
JOIN target.customers c
    ON o.customer_id = c.customer_id

GROUP BY customer_state
ORDER BY avg_freight_value DESC
LIMIT 5;


-- Q14. Top 5 states with lowest average freight value

SELECT
    customer_state,

    ROUND(
        AVG(freight_value),
        2
    ) AS avg_freight_value

FROM target.order_items oi
JOIN target.orders o
    ON oi.order_id = o.order_id
JOIN target.customers c
    ON o.customer_id = c.customer_id

GROUP BY customer_state
ORDER BY avg_freight_value
LIMIT 5;


-- Q15. Top 5 states with highest average delivery time

SELECT
    customer_state,

    ROUND(
        AVG(
            DATE_DIFF(
                order_delivered_customer_date,
                order_purchase_timestamp,
                DAY
            )
        ),
        2
    ) AS no_of_days_taken

FROM target.orders o
JOIN target.customers c
    ON o.customer_id = c.customer_id

GROUP BY customer_state
ORDER BY no_of_days_taken DESC
LIMIT 5;


-- Q16. Top 5 states with lowest average delivery time

SELECT
    customer_state,

    ROUND(
        AVG(
            DATE_DIFF(
                order_delivered_customer_date,
                order_purchase_timestamp,
                DAY
            )
        ),
        2
    ) AS no_of_days_taken

FROM target.orders o
JOIN target.customers c
    ON o.customer_id = c.customer_id

GROUP BY customer_state
ORDER BY no_of_days_taken
LIMIT 5;


-- Q17. States delivering faster than estimated

SELECT
    customer_state,

    ROUND(
        AVG(
            DATE_DIFF(
                order_estimated_delivery_date,
                order_delivered_customer_date,
                DAY
            )
        ),
        2
    ) AS avg_diff_estimated_delivery

FROM target.orders o
JOIN target.customers c
    ON o.customer_id = c.customer_id

GROUP BY customer_state
ORDER BY avg_diff_estimated_delivery DESC
LIMIT 5;


/* =====================================================================
   SECTION 7 : PAYMENT ANALYSIS
   ===================================================================== */

-- Q18. Month-on-month orders by payment type

SELECT DISTINCT
    EXTRACT(MONTH FROM order_delivered_customer_date) AS month,
    EXTRACT(YEAR FROM order_delivered_customer_date) AS payment_year,
    p.payment_type,

    COUNT(o.order_id)
    OVER
    (
        PARTITION BY
        payment_type,
        EXTRACT(MONTH FROM order_delivered_customer_date),
        EXTRACT(YEAR FROM order_delivered_customer_date)
    ) AS no_of_orders

FROM target.payments p
JOIN target.orders o
    ON p.order_id = o.order_id

ORDER BY month;


-- Q19. Orders based on payment installments

SELECT
    payment_installments,
    COUNT(order_id) AS no_of_orders
FROM target.payments
GROUP BY payment_installments
ORDER BY payment_installments;


/* =====================================================================
   END OF ANALYSIS
   ===================================================================== */