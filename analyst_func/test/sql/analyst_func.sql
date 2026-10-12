-- analyst_func regression test

set client_min_messages = warning;
drop extension if exists analyst_func cascade;
drop schema if exists af cascade;
reset client_min_messages;

create schema af;
create extension analyst_func schema af;
set search_path = af, public;

-- 1. odd count
select median(x) from (values (1), (2), (3)) as t(x);

-- 2. even count
select median(x) from (values (1), (2), (3), (4)) as t(x);

-- 3. single value
select median(x) from (values (42)) as t(x);

-- 4. NULL values ignored
select median(x) from (values (1), (null), (3)) as t(x);

-- 5. all NULLs
select median(x) from (values (null::numeric), (null::numeric)) as t(x);

-- 6. empty set
select median(x) from (values (1)) as t(x) where false;

-- 7. decimals (exact numeric arithmetic)
select median(x) from (values (1.5), (2.5), (3.5)) as t(x);
select median(x) from (values (1.1), (2.2), (3.3), (4.4)) as t(x);

-- 8. duplicates
select median(x) from (values (1), (1), (1)) as t(x);

-- 9. group by
select g, median(x)
from (values ('a', 1::numeric), ('a', 2), ('a', 3),
             ('b', 10), ('b', 20)) as t(g, x)
group by g
order by g;

-- 10. window function
select g, x, median(x) over (partition by g)
from (values ('a', 1::numeric), ('a', 2), ('a', 3)) as t(g, x)
order by g, x;

-- 11. moving window frame — sanity check
with t(x) as (
    values (1::numeric), (2), (3), (4), (5), (6), (7)
)
select
    x,
    median(x) over (
        order by x
        rows between 2 preceding and current row
    ) as m3
from t
order by x;

-- 11. moving window frame
with t(x) as (
    values (1::numeric), (2), (3), (4), (5), (6), (7)
)
select x, median(x) over (
    order by x
    rows between 2 preceding and current row
) as m3
from t
order by x;

-- 12. moving window with NULLs
with t(x) as (
    values (1::numeric), (null), (3), (null), (5)
)
select x, median(x) over (
    order by x nulls last
    rows between 2 preceding and current row
) as m3
from t
order by x nulls last;

