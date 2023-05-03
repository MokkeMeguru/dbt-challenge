with

user as (

  select * from {{ ref('stg_thelookec__users') }}

)

select
  id,
  first_name,
  last_name,
  age
from
  user
