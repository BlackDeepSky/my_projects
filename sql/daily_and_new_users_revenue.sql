--неотмененные заказы
with not_canceled_orders as (
SELECT order_id, user_id
FROM   user_actions ua
WHERE  action = 'create_order'
    and not exists(
    SELECT 1
    FROM   user_actions ua1
    WHERE  ua1.order_id = ua.order_id
    and action = 'cancel_order')
),

--выручка на пользователя
day_users_revenue as (
SELECT 
    date(creation_time) as date_revenue,
    user_id,
    sum(price) as revenue
FROM   orders 
cross join unnest(product_ids) as product_id
join products using(product_id)
join not_canceled_orders using(order_id)
GROUP BY date_revenue, user_id
),

--все новые пользователи
total_new_users as (
SELECT
    min(date(time)) as min_active_day,
    user_id
FROM user_actions
GROUP BY user_id
),

--выручка дневная
day_revenue as (
select 
    date_revenue,
    sum(revenue) as daily_revenue
from day_users_revenue
group by date_revenue
),

--выручка новых пользователей
new_users_revenue as (
select 
    date_revenue, 
    sum(revenue) as new_users_revenue
from day_users_revenue dur
join total_new_users tnu using(user_id)
where dur.date_revenue = tnu.min_active_day
group by date_revenue
)

select
    date_revenue as date,
    daily_revenue as revenue,
    coalesce(new_users_revenue, 0) as new_users_revenue,
    round(coalesce(new_users_revenue, 0)::numeric / nullif(daily_revenue, 0) * 100, 2) as new_users_revenue_share,
    100 - round(coalesce(new_users_revenue, 0)::numeric / nullif(daily_revenue, 0) * 100, 2) as old_users_revenue_share
from
    day_revenue
left join new_users_revenue using(date_revenue)
group by date_revenue, daily_revenue, new_users_revenue
