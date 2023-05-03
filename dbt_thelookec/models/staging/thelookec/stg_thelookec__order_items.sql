with

source as (

  select * from {{ source('thelookec', 'order_items') }}

)


select
  id,
  order_id,
  user_id,
  product_id,
  status,
  created_at,
  sale_price
from
  source
