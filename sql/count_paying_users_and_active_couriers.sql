with NEW_USERS as (
SELECT
    user_id,
    date(time) as date,
    min(date(time)) OVER(PARTITION BY user_id ORDER BY date(time)) as min_user_date
FROM
    user_actions
),
NEW_COURIERS as (
SELECT
    courier_id,
    date(time) as date,
    min(date(time)) OVER(PARTITION BY courier_id ORDER BY date(time)) as min_courier_date
FROM
    courier_actions
),
COUNT_NEW_USERS as (
SELECT
    date,
    count(distinct user_id) filter(where date=min_user_date) as new_users
FROM
    NEW_USERS
GROUP BY date
),
COUNT_NEW_COURIERS as (
SELECT
    date,
    count(distinct courier_id) filter(where date=min_courier_date) as new_couriers
FROM
    NEW_COURIERS
GROUP BY date
),
ALL_DATES AS (
  SELECT DATE(time) AS date FROM user_actions
  UNION
  SELECT DATE(time) AS date FROM courier_actions
),
DAILY_NEW AS (
  SELECT
    d.date,
    COALESCE(u.new_users, 0) AS new_users,
    COALESCE(c.new_couriers, 0) AS new_couriers
  FROM all_dates d
  LEFT JOIN COUNT_NEW_USERS u ON d.date = u.date
  LEFT JOIN COUNT_NEW_COURIERS c ON d.date = c.date
),
TOTAL_USERS_AND_COURIERS as (
SELECT
    date,
    sum(new_users::int) OVER(ORDER BY date) as total_users,
    sum(new_couriers::int) OVER(ORDER BY date) as total_couriers
FROM
    DAILY_NEW
),
PAYING_USERS as (
SELECT
    count(distinct user_id) as count_paying_users,
    date(time) as date
FROM
    user_actions ua
WHERE action = 'create_order' and
    not exists(
    SELECT order_id
    FROM user_actions ua1
    where ua1.order_id = ua.order_id and action = 'cancel_order'
    )
GROUP BY date
),
DELIVERED_ORDERS as (
SELECT
    courier_id,
    order_id,
    date(time) as activity_date
FROM
    courier_actions
WHERE action = 'deliver_order'
),
ACCEPTED_ORDERS as(
SELECT
    ca.courier_id,
    order_id,
    date(ca.time) as activity_date
FROM
    courier_actions ca
JOIN DELIVERED_ORDERS using(order_id)
WHERE action = 'accept_order'
),
ACTIVE_COURIERS_RAW as(
    SELECT courier_id, activity_date FROM DELIVERED_ORDERS
    union
    SELECT courier_id, activity_date FROM ACCEPTED_ORDERS
),
ACTIVE_COURIERS as (
    SELECT
        count(distinct courier_id) as count_active_couriers,
        activity_date as date
    FROM
        ACTIVE_COURIERS_RAW
    GROUP BY date
)
SELECT
    date,
    count_paying_users as paying_users,
    count_active_couriers as active_couriers,
    ROUND(100.0 * count_paying_users / NULLIF(total_users, 0), 2) AS paying_users_share,
    ROUND(100.0 * count_active_couriers / NULLIF(total_couriers, 0), 2) AS active_couriers_share
FROM
    TOTAL_USERS_AND_COURIERS
LEFT JOIN
    PAYING_USERS using(date)
LEFT JOIN
    ACTIVE_COURIERS using(date)
