-- Сначала получим все неотменённые заказы (без дублирования логики)
with not_canceled_orders as (
    select order_id
    from orders o
    where not exists (
        select 1
        from user_actions ua
        where ua.order_id = o.order_id
          and ua.action = 'cancel_order'
    )
),
-- Платящие пользователи
users_by_day as (
    select
        date(time) as date,
        count(distinct user_id) as count_users
    from user_actions
    join not_canceled_orders using(order_id)
    group by date
),
-- Активные курьеры
active_couriers as (
    select
        date(time) as date,
        count(distinct courier_id) as count_couriers
    from courier_actions
    join not_canceled_orders using(order_id)
    where action in ('accept_order', 'deliver_order')
    group by date
),
-- Заказы
count_orders as (
    select
        date(creation_time) as date,
        count(order_id) as count_orders
    from orders
    join not_canceled_orders using(order_id)
    group by date
)
-- Финальный расчёт
select
    date,
    round(count_users::decimal / count_couriers, 2) as users_per_courier,
    round(count_orders::decimal / count_couriers, 2) as orders_per_courier
from users_by_day
join count_orders using(date)
join active_couriers using(date)
order by date
