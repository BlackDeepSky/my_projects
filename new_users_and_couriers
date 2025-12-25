with new_users_and_couriers as (
SELECT
    user_id,
    courier_id,
    date(time) as date,
    min(date(time)) OVER(PARTITION BY user_id ORDER BY date(time)) as min_user_date_order,
    min(date(time)) OVER(PARTITION BY courier_id ORDER BY date(time)) as min_courier_date_order
FROM
    user_actions
join courier_actions using(time)
GROUP BY
    date, user_id, courier_id
),
count_new_users_and_couriers as (
SELECT
    date,
    count(distinct user_id) filter(where date=min_user_date_order) as new_users,
    count(distinct courier_id) filter(where date=min_courier_date_order) as new_couriers
FROM
    new_users_and_couriers
GROUP BY
    date
)
SELECT
    date,
    new_users,
    new_couriers,
    total_users,
    total_couriers,
    (new_users::numeric - lag(new_users) over(order by date)) / lag(new_users) over(order by date) * 100 as new_users_change,
    (new_couriers::numeric - lag(new_couriers) over(order by date)) / lag(new_couriers) over(order by date) * 100 as new_couriers_change,
    (total_users::numeric - lag(total_users) over(order by date)) / lag(total_users) over(order by date) * 100 as total_users_growth,
    (total_couriers::numeric - lag(total_couriers) over(order by date)) / lag(total_couriers) over(order by date) * 100 as total_couriers_growth
FROM
(
SELECT
    date,
    new_users,
    new_couriers,
    sum(new_users::int) over(order by date) as total_users,
    sum(new_couriers::int) over(order by date) as total_couriers
FROM
    count_new_users_and_couriers
GROUP BY
    date, new_users, new_couriers
) as t1
