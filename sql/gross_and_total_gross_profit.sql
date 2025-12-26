--неотмененные заказы
with not_canceled_orders as(
SELECT order_id
from user_actions ua
where not exists(
    select 1
    from user_actions ua1
    where ua.order_id = ua1.order_id and action = 'cancel_order'
)),

--выручка за день
revenue_per_day as(
SELECT
    date(creation_time) as date_revenue,
    sum(price) as revenue
from orders
cross join unnest(product_ids) as product_id
join products using(product_id)
join not_canceled_orders using(order_id)
group by date_revenue
),

--подсчет которые доставили >= 5 заказов
count_working_couriers as (
SELECT
    date_deliver,
    count(distinct courier_id) filter(where count_delivered_orders >= 5) as working_couriers
FROM
(
SELECT
    date(time) as date_deliver,
    courier_id,
    count(distinct order_id) filter(where action = 'deliver_order') as count_delivered_orders
FROM
    courier_actions
join not_canceled_orders using(order_id)
group by date_deliver, courier_id
) as t1
group by date_deliver
),

--подсчет количества заказов
count_orders_completed as (
SELECT
    date(creation_time) as  date_order,
    count(distinct order_id) as count_orders
from
    orders
join not_canceled_orders using(order_id)
group by date_order
),

--подсчет доставленных заказов
count_delivered_orders as (
SELECT
    date(time) as date_deliver,
    count(distinct order_id) filter(where action='deliver_order') as count_delivered_order
from
    courier_actions
join not_canceled_orders using(order_id)
group by date_deliver
),

--подсчет затрат
summary_costs as (
SELECT
    date_order,
    case
    when extract(month from date_order) < 9 
    then round(120000 + count_orders * 140 + count_delivered_order * 150 + working_couriers * 400,2)
    else 
    round(150000 + count_orders * 115 + count_delivered_order * 150 + working_couriers * 500,2)
    end as costs
from
    count_orders_completed coc
left join count_working_couriers cwc on cwc.date_deliver=coc.date_order
left join count_delivered_orders cdo on cdo.date_deliver=coc.date_order
order by date_order
),

--подсчет НДС
tax_in_products as(
SELECT
    DATE(creation_time) AS date_revenue,
    SUM(
        CASE
            WHEN name IN (
                'сахар', 'сухарики', 'сушки', 'семечки', 
                'масло льняное', 'виноград', 'масло оливковое', 
                'арбуз', 'батон', 'йогурт', 'сливки', 'гречка', 
                'овсянка', 'макароны', 'баранина', 'апельсины', 
                'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 
                'мука', 'шпроты', 'сосиски', 'свинина', 'рис', 
                'масло кунжутное', 'сгущенка', 'ананас', 'говядина', 
                'соль', 'рыба вяленая', 'масло подсолнечное', 'яблоки', 
                'груши', 'лепешка', 'молоко', 'курица', 'лаваш', 
                'вафли', 'мандарины'
            ) THEN ROUND((price * 10)/110,2)
            ELSE ROUND((price * 20)/120,2)
        END
    ) AS tax
FROM orders
CROSS JOIN UNNEST(product_ids) AS product_id
JOIN products USING(product_id)
JOIN not_canceled_orders USING(order_id)
GROUP BY date_revenue
)

--финальный подсчет
SELECT
    date_revenue as date,
    revenue,
    costs,
    tax,
    gross_profit,
    total_revenue,
    total_costs,
    total_tax,
    round(total_revenue - total_tax - total_costs,2) as total_gross_profit,
    round((gross_profit / revenue) * 100,2) as gross_profit_ratio,
    round((total_revenue - total_tax - total_costs) / total_revenue * 100,2) as total_gross_profit_ratio
FROM
(
SELECT
    date_revenue,
    revenue,
    costs,
    tax,
    round((revenue - costs - tax),2) as gross_profit,
    round(sum(revenue) over(order by date_revenue),2) as total_revenue,
    round(sum(costs) over(order by date_revenue),2) as total_costs,
    round(sum(tax) over(order by date_revenue),2) as total_tax
FROM
    revenue_per_day rpd
left join summary_costs sc on sc.date_order = rpd.date_revenue
left join tax_in_products using(date_revenue)
) as t1
