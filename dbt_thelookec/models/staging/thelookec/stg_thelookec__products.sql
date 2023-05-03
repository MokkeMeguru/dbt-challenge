with

source as (

  select * from {{ source('thelookec','products') }}

)

select
  id,
  category,
  brand,
  department,
  name
from source
