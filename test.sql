SELECT first_name, last_name, order_date, order_amount
from customers c
inner join orders o
on c.customer_id = o.customer_id
