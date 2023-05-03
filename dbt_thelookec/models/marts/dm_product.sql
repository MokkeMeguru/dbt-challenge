with

product as (

  select * from {{ ref('stg_thelookec__products') }}

)

select
  id,
  category,
  brand,
  department,
  name
from product
