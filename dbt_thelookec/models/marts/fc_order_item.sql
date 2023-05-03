with

order_items as (

  select * from {{ ref('stg_thelookec__order_items') }}

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
  order_items
