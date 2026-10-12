/* analyst_func--0.1.sql */

\echo Use "create extension analyst_func" to load this file. \quit

/* ======================================================================= */
/* median(numeric)                                                         */
/* ======================================================================= */

create function @extschema@.median_trans(
    state numeric[],
    val   numeric
) returns numeric[]
language plpgsql immutable strict parallel safe
as $$
begin
    if state is null then
        return array[val];
    end if;
    return array_append(state, val);
end $$;

comment on function @extschema@.median_trans(numeric[], numeric) is
    'analyst_func: internal transition function for median(numeric)';

create function @extschema@.median_final(
    state numeric[]
) returns numeric
language sql immutable strict parallel safe
as $$
    with sorted as (
        select array(select x from unnest(state) as x order by x) as a,
               array_length(state, 1) as n
    )
    select case
        when n is null then null
        when n % 2 = 1 then a[(n + 1) / 2]
        else trim_scale( (a[n / 2] + a[n / 2 + 1]) / 2)
    end
    from sorted
$$;

comment on function @extschema@.median_final(numeric[]) is
    'analyst_func: internal final function for median(numeric)';

create aggregate @extschema@.median(numeric) (
    sfunc     = @extschema@.median_trans,
    stype     = numeric[],
    initcond  = '{}',
    finalfunc = @extschema@.median_final,
    parallel  = safe
);

comment on aggregate @extschema@.median(numeric) is
    'analyst_func: median value, ignoring NULLs; exact numeric arithmetic';
