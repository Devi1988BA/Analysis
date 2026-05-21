create database marketplace_db;
use marketplace_db;

CREATE TABLE products (
    product_id      INT             NOT NULL,
    category        VARCHAR(20)     NOT NULL,
    sub_category    VARCHAR(20)     NOT NULL,
    brand           VARCHAR(20)         NULL,        -- some products have no brand
    supplier_id     INT                 NULL,
    cost_price      DECIMAL(10, 2)  NOT NULL,
    mrp             DECIMAL(10, 2)  NOT NULL,
    weight_kg       DECIMAL(6, 2)       NULL,
    launch_date     DATE                NULL,

    -- Primary Key
    CONSTRAINT pk_products PRIMARY KEY (product_id)
);

CREATE TABLE payment_fees (
    payment_method      VARCHAR(20)     NOT NULL,
    fee_percentage      DECIMAL(5, 2)   NOT NULL,   -- e.g. 1.2 = 1.2%
    settlement_days     INT             NOT NULL,

    PRIMARY KEY (payment_method)
);

CREATE TABLE orders (
    order_id        INT             NOT NULL,
    order_date      DATE            NOT NULL,
    customer_id     INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL,
    selling_price   DECIMAL(10, 2)  NOT NULL,
    order_status    VARCHAR(20)         NULL,   -- DELIVERED, SHIPPED, PENDING, CANCELLED
    payment_method  VARCHAR(20)         NULL,   -- FK to payment_fees
    order_channel   VARCHAR(20)         NULL,   -- APP, WEB, CALL_CENTER
    warehouse_id    INT                 NULL,

    PRIMARY KEY (order_id),

    -- FK → products: each order must reference a valid product
    CONSTRAINT fk_orders_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- FK → payment_fees: payment method must exist in lookup table
    CONSTRAINT fk_orders_payment
        FOREIGN KEY (payment_method)
        REFERENCES payment_fees (payment_method)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

CREATE TABLE discounts (
    discount_id         INT             NOT NULL,
    order_id            INT             NOT NULL,
    discount_amount     DECIMAL(10, 2)  NOT NULL,
    discount_type       VARCHAR(20)         NULL,   -- Coupon, BankOffer, Festival
    coupon_code         VARCHAR(30)         NULL,
    is_stackable        CHAR(1)             NULL,   -- Y / N

    PRIMARY KEY (discount_id),

    -- FK → orders: discount must belong to a valid order
    CONSTRAINT fk_discounts_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
CREATE TABLE logistics_cost (
    logistics_id            INT             NOT NULL,
    order_id                INT             NOT NULL,
    shipping_cost           DECIMAL(10, 2)  NOT NULL,
    reverse_shipping_cost   DECIMAL(10, 2)  NOT NULL DEFAULT 0.00,
    delivery_days           INT                 NULL,
    delivery_status         VARCHAR(20)         NULL,   -- ON_TIME, DELAYED, LOST

    PRIMARY KEY (logistics_id),

    -- FK → orders: logistics must belong to a valid order
    CONSTRAINT fk_logistics_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
CREATE TABLE returns (
    return_id               INT             NOT NULL,
    order_id                INT             NOT NULL,
    return_flag             CHAR(1)             NULL,   -- Y / N / X
    return_reason           VARCHAR(100)        NULL,
    return_initiated_date   DATE                NULL,
    refund_mode             VARCHAR(30)         NULL,   -- Original Payment, UPI, Wallet
    refund_status           VARCHAR(20)         NULL,   -- Processed, Pending, Rejected
    customer_fault_flag     CHAR(1)             NULL,   -- Y / N

    PRIMARY KEY (return_id),

    -- FK → orders: return must reference a valid order
    CONSTRAINT fk_returns_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

SET FOREIGN_KEY_CHECKS = 0;
select * from logistics_cost;

/*---------------------------------------Datacleaning----------------------------------*/

/*---------------------------------------Products Table----------------------------------*/

select * from products where cost_price<=0 or mrp<cost_price;

select count(*) from products where cost_price<=0 or mrp<cost_price;

SET SQL_SAFE_UPDATES = 0;

DELETE FROM products
WHERE cost_price <= 0 OR mrp < cost_price;

SELECT
    'products'                                                        AS table_name,
    COUNT(*)                                                          AS total_rows,
    SUM(CASE WHEN category     IS NULL OR category     = '' THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN sub_category IS NULL OR sub_category = '' THEN 1 ELSE 0 END) AS null_sub_category,
    SUM(CASE WHEN brand        IS NULL OR brand        = '' THEN 1 ELSE 0 END) AS null_brand,
    SUM(CASE WHEN supplier_id  IS NULL                      THEN 1 ELSE 0 END) AS null_supplier_id,
    SUM(CASE WHEN cost_price   IS NULL OR cost_price   = 0  THEN 1 ELSE 0 END) AS null_cost_price,
    SUM(CASE WHEN mrp          IS NULL OR mrp          = 0  THEN 1 ELSE 0 END) AS null_mrp,
    SUM(CASE WHEN weight_kg    IS NULL OR weight_kg    = 0  THEN 1 ELSE 0 END) AS null_weight_kg,
    SUM(CASE WHEN launch_date  IS NULL THEN 1 ELSE 0 END) AS null_launch_date
FROM products;
use marketplace_db;
select * from products where category='';
select * from products where brand='';
select count(*) from products where category='';
select count(*) from products where brand='';
select * from products where weight_kg=0 limit 10;
SELECT COUNT(*) FROM products WHERE weight_kg = 0;
SELECT brand, category, COUNT(*) AS count
FROM products
WHERE category!=''
GROUP BY brand, category
ORDER BY brand;

select count(*) FROM products p1
JOIN products p2
    ON p1.supplier_id = p2.supplier_id
WHERE p1.category = ''
  AND p2.category != '';
  
SELECT
    p1.product_id,
    p1.supplier_id,
    p1.category                AS current_null_category,
    p2.category                AS fill_from_supplier
FROM products p1
JOIN products p2
    ON p1.supplier_id = p2.supplier_id
WHERE p1.category = ''
  AND p2.category != '';
  
  UPDATE products p1
JOIN (
    SELECT supplier_id, category
    FROM products
    WHERE category !=''
    GROUP BY supplier_id, category
    ORDER BY COUNT(*) DESC
) p2 ON p1.supplier_id = p2.supplier_id
SET p1.category = p2.category
WHERE p1.category!='';

UPDATE products
SET category = 
    CASE 
        WHEN sub_category LIKE '%Electronics%' THEN 'Electronics'
        WHEN sub_category LIKE '%Fashion%'     THEN 'Fashion'
        WHEN sub_category LIKE '%Beauty%'      THEN 'Beauty'
        WHEN sub_category LIKE '%Grocery%'     THEN 'Grocery'
        WHEN sub_category LIKE '%Home%'        THEN 'Home'
        ELSE 'Unknown'
    END
WHERE category='';

select * from products where category='Unknown';

SELECT
    p1.product_id,
    p1.supplier_id,
    p1.category,
    p1.brand                AS current_brand,
    p2.brand                AS will_be_filled_with
FROM products p1
JOIN (
    SELECT supplier_id, brand
    FROM products
    WHERE brand IS NOT NULL
    GROUP BY supplier_id, brand
    ORDER BY COUNT(*) DESC
) p2 ON p1.supplier_id = p2.supplier_id
WHERE p1.brand=''
Limit 10;

UPDATE products p1
JOIN (
    SELECT supplier_id, brand
    FROM products
    WHERE brand IS NOT NULL
    GROUP BY supplier_id, brand
    ORDER BY COUNT(*) DESC
) p2 ON p1.supplier_id = p2.supplier_id
SET p1.brand = p2.brand
WHERE p1.brand='';

SELECT COUNT(*) AS null_brand_remaining
FROM products
WHERE brand='';

SELECT
    p1.product_id,
    p1.supplier_id,
    p1.category,
    p1.brand
FROM products p1
WHERE p1.brand=''
ORDER BY p1.supplier_id
LIMIT 20;

SELECT DISTINCT
    p1.supplier_id        AS null_brand_supplier,
    p2.brand              AS brand_from_same_supplier
FROM products p1
JOIN products p2
    ON p1.supplier_id = p2.supplier_id
WHERE p1.brand=''
  AND p2.brand!=''
ORDER BY p1.supplier_id;

UPDATE products p1
JOIN (
    SELECT   category,
             brand,
             COUNT(*) AS cnt
    FROM     products
    WHERE    brand!=''
    GROUP BY category, brand
    ORDER BY cnt DESC
) p2 ON p1.category = p2.category
SET p1.brand = p2.brand
WHERE p1.brand='';

SELECT 
    p1.product_id,
    p1.brand,
    p1.category           AS current_unknown,
    p2.category           AS derived_from_brand
FROM products p1
JOIN products p2 
    ON p1.brand = p2.brand
WHERE p1.category = 'Unknown'
  AND p2.category != 'Unknown'
LIMIT 10;

UPDATE products p1
JOIN (
    SELECT brand, category
    FROM products
    WHERE category != 'Unknown'
      AND brand IS NOT NULL
    GROUP BY brand, category
    ORDER BY COUNT(*) DESC
) p2 ON p1.brand = p2.brand
SET p1.category = p2.category
WHERE p1.category = 'Unknown';


use marketplace_db;
SELECT COUNT(*) AS still_unknown 
FROM products WHERE category = 'Unknown';
select * from products;
select * from products where category = 'unknown';
select * from products where brand ='unknown';
SELECT COUNT(*) AS null_brand_remaining
FROM products WHERE brand='';

/*-----------------------Orders Table-----------------------------------------------*/

SELECT
    'orders',
    COUNT(*),
    SUM(CASE WHEN order_date     IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN customer_id    IS NULL                        THEN 1 ELSE 0 END),
    SUM(CASE WHEN product_id     IS NULL                        THEN 1 ELSE 0 END),
    SUM(CASE WHEN quantity       IS NULL OR quantity       = 0  THEN 1 ELSE 0 END),
    SUM(CASE WHEN selling_price  IS NULL OR selling_price  = 0  THEN 1 ELSE 0 END),
    SUM(CASE WHEN order_status   IS NULL OR order_status   = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN payment_method IS NULL OR payment_method = '' OR payment_method = 'INVALID' THEN 1 ELSE 0 END),
    SUM(CASE WHEN order_channel  IS NULL OR order_channel  = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN warehouse_id   IS NULL                        THEN 1 ELSE 0 END)
FROM orders;

-- Step 2: Fill NULL order_channel with most frequent value
UPDATE orders
SET order_channel = (
    SELECT order_channel FROM (
        SELECT order_channel, COUNT(*) AS cnt
        FROM orders
        WHERE order_channel IS NOT NULL
        AND order_channel != ''
        GROUP BY order_channel
        ORDER BY cnt DESC
        LIMIT 1
    ) t
)
WHERE order_channel IS NULL
   OR order_channel = '';
   
   SELECT COUNT(*) AS null_order_channel
FROM orders
WHERE order_channel IS NULL OR order_channel = '';

UPDATE orders
SET order_status = (
    SELECT order_status FROM (
        SELECT order_status, COUNT(*) AS cnt
        FROM orders
        WHERE order_status IS NOT NULL
        AND order_status != ''
        GROUP BY order_status
        ORDER BY cnt DESC
        LIMIT 1
    ) t
)
WHERE order_status IS NULL
   OR order_status = '';
   
   SELECT COUNT(*) AS null_order_status
FROM orders
WHERE order_status IS NULL OR order_status = '';

/*---------------------------------discount table----------------------------------------*/

SELECT
    'discounts',
    COUNT(*),
    SUM(CASE WHEN order_id        IS NULL                         THEN 1 ELSE 0 END),
    SUM(CASE WHEN discount_amount IS NULL OR discount_amount = 0  THEN 1 ELSE 0 END),
    SUM(CASE WHEN discount_type   IS NULL OR discount_type   = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN coupon_code     IS NULL OR coupon_code     = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_stackable    IS NULL OR is_stackable    = '' THEN 1 ELSE 0 END)
FROM discounts;

SELECT discount_type, COUNT(*) AS count
FROM discounts
WHERE discount_type is not null
GROUP BY discount_type
ORDER BY count DESC;

UPDATE discounts
SET discount_type = (
    SELECT discount_type
    FROM (
        SELECT discount_type, COUNT(*) AS cnt
        FROM discounts
        WHERE discount_type!=''
        GROUP BY discount_type
        ORDER BY cnt DESC
        LIMIT 1
    ) AS top_type
)
WHERE discount_type='';

SELECT coupon_code, COUNT(*) AS count
FROM discounts
WHERE coupon_code is not null
GROUP BY coupon_code
ORDER BY count DESC;
select * from discounts where coupon_code='' limit 100;

UPDATE discounts
SET coupon_code = (
    SELECT coupon_code
    FROM (
        SELECT coupon_code, COUNT(*) AS cnt
        FROM discounts
        WHERE coupon_code !=''
        GROUP BY coupon_code
        ORDER BY cnt DESC
        LIMIT 1
    ) AS top_code
)
WHERE coupon_code='';

SELECT is_stackable, COUNT(*) AS count
FROM discounts
WHERE is_stackable IS NOT NULL
GROUP BY is_stackable
ORDER BY count DESC;

UPDATE discounts
SET is_stackable = (
    SELECT is_stackable
    FROM (
        SELECT is_stackable, COUNT(*) AS cnt
        FROM discounts
        WHERE is_stackable !=''
        GROUP BY is_stackable
        ORDER BY cnt DESC
        LIMIT 1
    ) AS top_stack
)
WHERE is_stackable='';

SELECT
    'discounts'     AS table_name,
    COUNT(*)        AS linked_records
FROM discounts
WHERE order_id IN (SELECT order_id FROM orders WHERE quantity = 0 OR selling_price = 0)
UNION ALL
SELECT
    'returns',
    COUNT(*)
FROM returns
WHERE order_id IN (SELECT order_id FROM orders WHERE quantity = 0 OR selling_price = 0)
UNION ALL
SELECT
    'logistics_cost',
    COUNT(*)
FROM logistics_cost
WHERE order_id IN (SELECT order_id FROM orders WHERE quantity = 0 OR selling_price = 0);


SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

-- Step 1: Delete from discounts
DELETE FROM discounts
WHERE order_id IN (
    SELECT order_id FROM (
        SELECT order_id FROM orders
        WHERE quantity = 0 OR selling_price = 0
    ) t
);

-- Step 2: Delete from returns
DELETE FROM returns
WHERE order_id IN (
    SELECT order_id FROM (
        SELECT order_id FROM orders
        WHERE quantity = 0 OR selling_price = 0
    ) t
);

-- Step 3: Delete from logistics_cost
DELETE FROM logistics_cost
WHERE order_id IN (
    SELECT order_id FROM (
        SELECT order_id FROM orders
        WHERE quantity = 0 OR selling_price = 0
    ) t
);

-- Step 4: Finally delete from orders
DELETE FROM orders
WHERE quantity = 0 OR selling_price = 0;

SELECT 'orders'        AS table_name, COUNT(*) AS remaining_rows FROM orders
UNION ALL
SELECT 'discounts',                   COUNT(*) FROM discounts
UNION ALL
SELECT 'returns',                     COUNT(*) FROM returns
UNION ALL
SELECT 'logistics_cost',              COUNT(*) FROM logistics_cost;

/*---------------------------------returns table----------------------------------------*/
use marketplace_db;
SELECT
    'returns',
    COUNT(*),
    SUM(CASE WHEN order_id              IS NULL OR order_id              = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN return_flag           IS NULL OR return_flag           = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN return_reason         IS NULL OR return_reason         = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN return_initiated_date IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN refund_mode           IS NULL OR refund_mode           = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN refund_status         IS NULL OR refund_status         = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN customer_fault_flag   IS NULL OR customer_fault_flag   = '' THEN 1 ELSE 0 END)
FROM returns;

UPDATE returns
SET return_reason = 'Not Specified'
where return_reason='';

SELECT refund_mode, COUNT(*) AS count
FROM returns
GROUP BY refund_mode
ORDER BY count DESC;

UPDATE returns
SET refund_mode = 'UPI'
WHERE refund_mode ='';

SELECT refund_status, COUNT(*) AS count
FROM returns
GROUP BY refund_status
ORDER BY count DESC;

UPDATE returns
SET refund_status = 'Processed'
WHERE refund_status='';

SELECT customer_fault_flag, COUNT(*) AS count
FROM returns
GROUP BY customer_fault_flag
ORDER BY count DESC;

set SQL_SAFE_UPDATES=0;

UPDATE returns
SET customer_fault_flag = 'Y'
WHERE customer_fault_flag='';

/*---------------------------------logistics cost table----------------------------------------*/

SELECT
    'logistics_cost',
    COUNT(*),
    SUM(CASE WHEN order_id               IS NULL                        THEN 1 ELSE 0 END),
    SUM(CASE WHEN shipping_cost          IS NULL OR shipping_cost < 0   THEN 1 ELSE 0 END),
    SUM(CASE WHEN reverse_shipping_cost  IS NULL                        THEN 1 ELSE 0 END),
    SUM(CASE WHEN delivery_days          IS NULL OR delivery_days  = 0  THEN 1 ELSE 0 END),
    SUM(CASE WHEN delivery_status        IS NULL OR delivery_status = '' THEN 1 ELSE 0 END)
FROM logistics_cost;
use marketplace_db;
select * from logistics_cost where delivery_days IS NULL OR delivery_days  = 0 or delivery_days='' or delivery_days=' ';
SELECT ROUND(AVG(shipping_cost), 2) AS avg_shipping
FROM logistics_cost
WHERE shipping_cost > 0;

UPDATE logistics_cost
SET shipping_cost = (
    SELECT avg_ship FROM (
        SELECT ROUND(AVG(shipping_cost), 2) AS avg_ship
        FROM logistics_cost
        WHERE shipping_cost > 0
    ) t
)
WHERE shipping_cost < 0;

SELECT ROUND(AVG(shipping_cost), 2) AS avg_shipping
FROM logistics_cost
WHERE shipping_cost > 0;

select * from logistics_cost;
select * from logistics_cost where delivery_status='';
select count(*) from logistics_cost where delivery_status='';





SELECT COUNT(*) AS negative_shipping
FROM logistics_cost
WHERE shipping_cost < 0;

SELECT * 
FROM logistics_cost
WHERE shipping_cost < 0;

SELECT COUNT(*) AS delivery_days_nulls
FROM logistics_cost WHERE delivery_days is null;

SELECT delivery_status, COUNT(*) AS count
FROM logistics_cost
WHERE delivery_status is not null
GROUP BY delivery_status
ORDER BY count DESC;

UPDATE logistics_cost
SET delivery_status = (
    SELECT delivery_status FROM (
        SELECT delivery_status, COUNT(*) AS cnt
        FROM logistics_cost
        WHERE delivery_status !=''
        GROUP BY delivery_status
        ORDER BY cnt DESC
        LIMIT 1
    ) t
)
WHERE delivery_status='';

/*-------------------------------------------Payment fees table----------------------------------------*/
use marketplace_db;
SELECT
    'payment_fees',
    COUNT(*),
    SUM(CASE WHEN payment_method  IS NULL OR payment_method  = '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN fee_percentage  IS NULL OR fee_percentage  = 0  THEN 1 ELSE 0 END),
    SUM(CASE WHEN settlement_days IS NULL OR settlement_days = 0  THEN 1 ELSE 0 END)
FROM payment_fees;

/*----------------------vw_order_summary table------------------------------------------------------------------------*/

CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    o.product_id,
    p.category,
    p.brand,
    p.sub_category,
    o.order_date,
    o.quantity,
    o.order_status,
    o.order_channel,
    o.warehouse_id,
    o.payment_method,

    -- Revenue
    (o.quantity * p.mrp)                                        AS gross_revenue,

    -- Product Cost
    (o.quantity * p.cost_price)                                 AS total_cost,

    -- Discount (0 if no discount record)
    COALESCE(d.discount_amount, 0)                              AS discount_amount,

    -- Net Revenue after discount
    (o.quantity * p.mrp) - COALESCE(d.discount_amount, 0)      AS net_revenue,

    -- Logistics (forward + reverse shipping)
    COALESCE(lc.shipping_cost, 0)                               AS shipping_cost,
    COALESCE(lc.reverse_shipping_cost, 0)                       AS reverse_shipping_cost,
    COALESCE(lc.shipping_cost, 0)
        + COALESCE(lc.reverse_shipping_cost, 0)                 AS total_logistics,

    -- Delivery info
    lc.delivery_days,
    lc.delivery_status,

    -- Payment fee (calculated from fee_percentage)
    COALESCE(
        ROUND((o.quantity * p.mrp) * pf.fee_percentage / 100, 2)
    , 0)                                                        AS payment_fee,

    -- Return info
    CASE WHEN r.return_id IS NOT NULL THEN 1 ELSE 0 END         AS is_returned,
    COALESCE(r.return_reason, 'No Return')                      AS return_reason,
    COALESCE(r.refund_status, 'NA')                             AS refund_status,

    -- Net Profit
    -- If returned: revenue is 0, but cost + logistics + fee still incurred
    -- If not returned: net revenue - cost - logistics - payment fee
    CASE
        WHEN r.return_id IS NOT NULL THEN
            0
            - (o.quantity * p.cost_price)
            - COALESCE(lc.shipping_cost, 0)
            - COALESCE(lc.reverse_shipping_cost, 0)
            - COALESCE(
                ROUND((o.quantity * p.mrp) * pf.fee_percentage / 100, 2)
              , 0)
        ELSE
            (o.quantity * p.mrp)
            - COALESCE(d.discount_amount, 0)
            - (o.quantity * p.cost_price)
            - COALESCE(lc.shipping_cost, 0)
            - COALESCE(lc.reverse_shipping_cost, 0)
            - COALESCE(
                ROUND((o.quantity * p.mrp) * pf.fee_percentage / 100, 2)
              , 0)
    END                                                         AS net_profit

FROM orders o
JOIN     products        p   ON o.product_id    = p.product_id
LEFT JOIN discounts      d   ON o.order_id      = d.order_id
LEFT JOIN returns        r   ON o.order_id      = r.order_id
LEFT JOIN logistics_cost lc  ON o.order_id      = lc.order_id
LEFT JOIN payment_fees   pf  ON o.payment_method = pf.payment_method;


SELECT * FROM vw_order_summary LIMIT 10;
SELECT * FROM vw_order_summary where delivery_days is null or delivery_status is null;
select count(*) from vw_order_summary where delivery_days is null or delivery_status is null;

select * from vw_order_summary where category='unknown';



SELECT
    TABLE_NAME        AS child_table,
    COLUMN_NAME       AS child_column,
    REFERENCED_TABLE_NAME  AS parent_table,
    REFERENCED_COLUMN_NAME AS parent_column
FROM
    INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE
    REFERENCED_TABLE_NAME IS NOT NULL
    AND TABLE_SCHEMA = 'marketplace_db'
ORDER BY
    TABLE_NAME;
    
    SELECT o.order_id, o.order_date, o.order_status
FROM orders o
LEFT JOIN logistics_cost lc ON o.order_id = lc.order_id
WHERE lc.order_id IS NULL
LIMIT 10;

INSERT INTO logistics_cost (order_id, shipping_cost, reverse_shipping_cost, delivery_days, delivery_status)
SELECT
    o.order_id,
    0                                    AS shipping_cost,
    0                                    AS reverse_shipping_cost,
    (SELECT ROUND(AVG(delivery_days),0)
     FROM logistics_cost
     WHERE delivery_days IS NOT NULL)    AS delivery_days,
    'ON_TIME'                            AS delivery_status
FROM orders o
LEFT JOIN logistics_cost lc ON o.order_id = lc.order_id
WHERE lc.order_id IS NULL;
select * from logistics_cost limit 10;
select * from logistics_cost where delivery_days='' limit 10;
UPDATE logistics_cost
SET delivery_days = (
    SELECT avg_days FROM (
        SELECT ROUND(AVG(delivery_days), 0) AS avg_days
        FROM logistics_cost
        WHERE delivery_days IS NOT NULL
    ) t
)
WHERE delivery_days IS NULL;
/*-------------------------------------------------------------------------------------------------*/
/*-------------------------------Vw_order_summary_table----------------------------------------*/
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    o.product_id,
    p.category,
    p.brand,
    p.sub_category,
    o.order_date,
    o.quantity,
    o.order_status,
    o.order_channel,
    o.warehouse_id,
    o.payment_method,
    -- Revenue
    (o.quantity * p.mrp)                                              AS gross_revenue,
    -- Product Cost
    (o.quantity * p.cost_price)                                       AS total_cost,
    -- Discount
    COALESCE(d.discount_amount, 0)                                    AS discount_amount,
    -- Net Revenue
    (o.quantity * p.mrp) - COALESCE(d.discount_amount, 0)            AS net_revenue,
    -- Logistics
    COALESCE(lc.shipping_cost, 0)                                     AS shipping_cost,
    COALESCE(lc.reverse_shipping_cost, 0)                             AS reverse_shipping_cost,
    COALESCE(lc.shipping_cost, 0)
        + COALESCE(lc.reverse_shipping_cost, 0)                      AS total_logistics,
    -- ✅ COALESCE fixes NULL delivery_days → default 6
    COALESCE(lc.delivery_days, 6)                                     AS delivery_days,
    -- ✅ COALESCE fixes NULL delivery_status → default ON_TIME
    COALESCE(lc.delivery_status, 'ON_TIME')                          AS delivery_status,
    -- Payment Fee
    COALESCE(
        ROUND((o.quantity * p.mrp) * pf.fee_percentage / 100, 2)
    , 0)                                                              AS payment_fee,
    -- Return Info
    CASE WHEN r.return_id IS NOT NULL THEN 1 ELSE 0 END              AS is_returned,
    COALESCE(r.return_reason, 'No Return')                           AS return_reason,
    COALESCE(r.refund_status, 'NA')                                  AS refund_status,
    -- Net Profit
    CASE
        WHEN r.return_id IS NOT NULL THEN
            0
            - (o.quantity * p.cost_price)
            - COALESCE(lc.shipping_cost, 0)
            - COALESCE(lc.reverse_shipping_cost, 0)
            - COALESCE(
                ROUND((o.quantity * p.mrp) * pf.fee_percentage / 100, 2)
              , 0)
        ELSE
            (o.quantity * p.mrp)
            - COALESCE(d.discount_amount, 0)
            - (o.quantity * p.cost_price)
            - COALESCE(lc.shipping_cost, 0)
            - COALESCE(lc.reverse_shipping_cost, 0)
            - COALESCE(
                ROUND((o.quantity * p.mrp) * pf.fee_percentage / 100, 2)
              , 0)
    END                                                               AS net_profit
FROM orders o
JOIN      products        p   ON o.product_id     = p.product_id
LEFT JOIN discounts       d   ON o.order_id       = d.order_id
LEFT JOIN returns         r   ON o.order_id       = r.order_id
LEFT JOIN logistics_cost  lc  ON o.order_id       = lc.order_id
LEFT JOIN payment_fees    pf  ON o.payment_method = pf.payment_method;
/*-------------------------------Vw_order_summary_table----------------------------------------*/
select * from vw_order_summary where refund_status='NA' limit 10;
select count(*) from vw_order_summary;
select * from returns where refund_status='NA';
use marketplace_db;
select * from vw_order_summary limit 10;
SELECT
    refund_status,
    COUNT(*) AS order_count
FROM vw_order_summary
GROUP BY refund_status
ORDER BY order_count DESC;

SELECT
    is_returned,
    COUNT(*) AS orders
FROM vw_order_summary
GROUP BY is_returned;

sql-- NA count should exactly match non-returned orders
SELECT
    is_returned,
    COUNT(*) AS orders
FROM vw_order_summary
GROUP BY is_returned;
```

| is_returned | Orders | Meaning |
|---|---|---|
| **0** | 12,985 | Not returned → refund_status = NA ✅ |
| **1** | 2,781 | Returned → has actual refund_status |

---

## Total = 15,766
```
12,985  non-returned  (refund_status = NA)
 2,781  returned      (refund_status = Processed / Pending / Rejected)
──────
15,766  total orders