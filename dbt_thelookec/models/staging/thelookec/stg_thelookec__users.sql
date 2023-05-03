with

source as (

  select * from {{ source('thelookec','users') }}

)

select
  id,
  first_name,
  last_name,
  age
from
  source
