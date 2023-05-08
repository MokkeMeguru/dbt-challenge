with

user as (

  select * from {{ ref('stg_thelookec__users') }}

)

select
  id,
  firstName,
  last_name,
  age
from
  user
