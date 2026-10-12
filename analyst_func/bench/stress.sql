\set ON_ERROR_STOP on
\set QUIET on
\timing off
\pset format unaligned
\pset tuples_only on

set client_min_messages = warning;

drop schema if exists bench cascade;
create schema bench;
create extension analyst_func schema bench;
set search_path = bench, public;

drop table if exists bench_data;
create table bench_data (
    id serial primary key,
    g  int,
    x  numeric,
    y  double precision
);

with r as (
    select (random() * 100000)::numeric(12,4) as x
    from generate_series(1, :cnt)
)
insert into bench_data (g, x, y)
select
    case when random() < 0.5 then 0
         else (random() * 99 + 1)::int
    end,
    x,
    x::double precision
from r;

analyze bench_data;

create temp table bench_results (
    method text,
    us     bigint
);

do $$
declare
    t0        timestamptz;
    win_limit int := 10000;
begin
        -- 1. cumulative: median(numeric) over the whole big group
    t0 := clock_timestamp();
    perform (select median(x) from bench_data where g = 0);
    insert into bench_results
    select 'cumulative',
           round(extract(epoch from clock_timestamp() - t0) * 1000000)::bigint;

    -- 2. cumulative_pct: percentile_cont(0.5) over the same
    t0 := clock_timestamp();
    perform (
        select percentile_cont(0.5) within group (order by y)
        from bench_data where g = 0
    );
    insert into bench_results
    select 'cumulative_pct',
           round(extract(epoch from clock_timestamp() - t0) * 1000000)::bigint;

    -- 3. window: median(numeric) moving frame, first win_limit rows
    t0 := clock_timestamp();
    perform (
        select sum(m) from (
            select median(x) over (
                order by id
                rows between 100 preceding and current row
            ) as m
            from (select * from bench_data limit win_limit) t
        ) s
    );
    insert into bench_results
    select 'window',
           round(extract(epoch from clock_timestamp() - t0) * 1000000)::bigint;

end $$;

select :cnt, method, us from bench_results order by method;

drop schema bench cascade;

