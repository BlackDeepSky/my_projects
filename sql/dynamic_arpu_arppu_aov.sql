--все новые пользователи
with total_new_users as (SELECT min_active_day,
count(distinct user_id) as count_new_users
FROM
  (
    SELECT
      min(date(time)) as min_active_day,
      user_id
    FROM
      user_actions
    GROUP BY
      user_id
  ) as new_users
GROUP BY
  min_active_day
),

--неотмененные заказы
not_canceled_orders as (SELECT order_id
FROM
  user_actions ua
WHERE
  not exists(
    SELECT
      1
    FROM
      user_actions ua1
    WHERE
      ua1.order_id = ua.order_id 
      and action = 'cancel_order'
  )
),

--новые платящие пользователи
total_new_paying_users as (
  SELECT
    min_active_day,
    count(distinct user_id) as count_new_paying_users
  FROM
    (
      SELECT
        min(date(time)) as min_active_day,
        user_id
      FROM
        user_actions
        join not_canceled_orders using(order_id)
      GROUP BY
        user_id
    ) as new_paying_users
  GROUP BY
    min_active_day
),

--выручка за день
day_revenue as (SELECT date(creation_time) as date_revenue,
sum(price) as revenue,
count(distinct order_id) as count_orders
FROM
  orders
  cross join unnest(product_ids) as product_id
  join products using(product_id)
  join not_canceled_orders using(order_id)
GROUP BY
  date_revenue
)
SELECT
  date_revenue as date,
  round(
    sum(revenue :: numeric) OVER(
      ORDER BY
        date_revenue
    ) / sum(count_new_users) OVER(
      ORDER BY
        date_revenue
    ),
    2
  ) as running_arpu,
  round(
    sum(revenue :: numeric) OVER(
      ORDER BY
        date_revenue
    ) / sum(count_new_paying_users) OVER(
      ORDER BY
        date_revenue
    ),
    2
  ) as running_arppu,
  round(
    sum(revenue :: numeric) OVER(
      ORDER BY
        date_revenue
    ) / sum(count_orders) OVER(
      ORDER BY
        date_revenue
    ),
    2
  ) as running_aov
FROM
  day_revenue dr
  join total_new_users tnu ON tnu.min_active_day = dr.date_revenue
  join total_new_paying_users tnpu ON tnpu.min_active_day = dr.date_revenue