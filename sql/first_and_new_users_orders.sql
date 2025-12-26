-- 1. День первого действия (любое действие)
with user_first_action as (
    select
        user_id,
        min(date(time)) as first_action_date
    from user_actions
    group by user_id
),

-- 2. Неотменённые заказы
not_canceled_orders as (
    select
        date(time) as order_date,
        user_id,
        order_id
    from user_actions ua
    where action = 'create_order'
      and not exists (
          select 1
          from user_actions ua2
          where ua2.order_id = ua.order_id
            and ua2.action = 'cancel_order'
      )
),

-- 3. День первого неотменённого заказа для каждого пользователя
user_first_order as (
    select
        user_id,
        min(order_date) as first_order_date
    from not_canceled_orders
    group by user_id
),

-- 4. Объединяем всё
final_orders as (
    select
        nco.order_date,
        nco.user_id,
        nco.order_id,
        ufa.first_action_date,
        ufo.first_order_date
    from not_canceled_orders nco
    join user_first_action ufa using(user_id)
    join user_first_order ufo using(user_id)
)

-- 5. Агрегация
select
    order_date as date,
    count(order_id) as orders,
    count(distinct user_id) filter (where order_date = first_order_date) as first_orders,
    count(order_id) filter (where order_date = first_action_date) as new_users_orders,
    round(100.0 * count(distinct user_id) filter (where order_date = first_order_date) / count(order_id), 2) as first_orders_share,
    round(100.0 * count(order_id) filter (where order_date = first_action_date) / count(order_id), 2) as new_users_orders_share
from final_orders
group by order_date
order by order_date
