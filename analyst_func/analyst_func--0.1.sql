/* analyst_func--0.1.sql */

\echo Use "create extension analyst_func" to load this file. \quit

/* ======================================================================= */
/* state type and helpers                                                  */
/* ======================================================================= */

create type @extschema@.median_state as (
    vals numeric[],
    skip int
);

comment on type @extschema@.median_state is
    'analyst_func: internal state for median(numeric)';

create function @extschema@.median_trans(
    state @extschema@.median_state,
    val   numeric
) returns @extschema@.median_state
language plpgsql immutable
as $$
begin
    if state is null then
        return row(array[val], 0)::@extschema@.median_state;
    end if;
    state.vals := state.vals || val;
    return state;
end $$;

comment on function @extschema@.median_trans(@extschema@.median_state, numeric) is
    'analyst_func: internal transition; appends, including NULLs';

create function @extschema@.median_minvfunc(
    state @extschema@.median_state,
    val   numeric
) returns @extschema@.median_state
language plpgsql immutable
as $$
begin
    if state is null then
        return state;
    end if;
    state.skip := coalesce(state.skip, 0) + 1;
    return state;
end $$;

comment on function @extschema@.median_minvfunc(@extschema@.median_state, numeric) is
    'analyst_func: internal inverse transition; advances skip counter';

create function @extschema@.median_final(
    state @extschema@.median_state
) returns numeric
language plpgsql immutable
as $$
declare
    active numeric[];
    n      int;
begin
    if state is null or state.vals is null then
        return null;
    end if;

    active := state.vals[
        coalesce(state.skip, 0) + 1 :
        coalesce(array_length(state.vals, 1), 0)
    ];

    active := array(
        select x
        from unnest(active) as x
        where x is not null
        order by x
    );

    n := coalesce(array_length(active, 1), 0);
    if n = 0 then
        return null;
    end if;

    if n % 2 = 1 then
        return active[(n + 1) / 2];
    else
        return trim_scale((active[n / 2] + active[n / 2 + 1]) / 2);
    end if;
end $$;

comment on function @extschema@.median_final(@extschema@.median_state) is
    'analyst_func: internal final; slices active window and computes median';

create function @extschema@.median_combine(
    s1 @extschema@.median_state,
    s2 @extschema@.median_state
) returns @extschema@.median_state
language sql immutable
as $$
    select case
        when s1 is null then s2
        when s2 is null then s1
        else row(
            coalesce(s1.vals, '{}'::numeric[]) ||
            coalesce(s2.vals, '{}'::numeric[]),
            0
        )::@extschema@.median_state
    end
$$;

comment on function @extschema@.median_combine(@extschema@.median_state, @extschema@.median_state) is
    'analyst_func: internal combine; assumes skip = 0 (parallel GROUP BY only)';


create aggregate @extschema@.median(numeric) (
    sfunc       = @extschema@.median_trans,
    stype       = @extschema@.median_state,
    msfunc      = @extschema@.median_trans,
    minvfunc    = @extschema@.median_minvfunc,
    mstype      = @extschema@.median_state,
    mfinalfunc  = @extschema@.median_final,
    combinefunc = @extschema@.median_combine,
    finalfunc   = @extschema@.median_final,
    parallel    = safe
);

comment on aggregate @extschema@.median(numeric) is
    'analyst_func: median of numeric values, supports moving window frames';

