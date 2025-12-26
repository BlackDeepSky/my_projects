SELECT
    active_date as date,
    round(count(distinct user_id) filter(where count_orders = 1) * 100 / count(user_id)::decimal,2) as single_order_users_share,
    round(count(distinct user_id) filter(where count_orders > 1) * 100 / count(user_id)::decimal,2) as several_orders_users_share
FROM    
(
SELECT
    date(time) as active_date,
    user_id,
    count(order_id) as count_orders
FROM
    user_actions ua
WHERE action = 'create_order' and
    not exists(
    SELECT order_id
    FROM user_actions ua1
    where ua1.order_id = ua.order_id and action = 'cancel_order'
    )
group by active_date, user_id
) as t1
group by active_date
