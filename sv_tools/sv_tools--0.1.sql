/* sv_tools--0.1.sql */

\echo Use "create extension sv_tools" to load this file. \quit

/* ----------------------------------------------------------------------- */
/* domain: only the types we support                                       */
/* ----------------------------------------------------------------------- */

create domain sv_regtype as regtype
constraint sv_regtype_supported check (
    value in (
        'int4'::regtype,
        'int8'::regtype,
        'float8'::regtype,
        'numeric'::regtype,
        'text'::regtype,
        'bool'::regtype,
        'jsonb'::regtype
    )
);

comment on domain sv_regtype is
    'sv_tools: supported data types for session variables';

/* ----------------------------------------------------------------------- */
/* internal: lazily create the temp table                                  */
/* ----------------------------------------------------------------------- */

create function sv__ensure_table()
returns void
language plpgsql
set search_path = @extschema@, pg_temp
as $$
begin
    if to_regclass('pg_temp.sv_session_vars') is null then
        create temp table sv_session_vars (
            var_name         text primary key,
            var_type         sv_regtype not null,
            var_value_int    int,
            var_value_bigint bigint,
            var_value_float  double precision,
            var_value_num    numeric,
            var_value_text   text,
            var_value_bool   boolean,
            var_value_json   jsonb,
            updated_at       timestamptz not null default now()
        ) on commit preserve rows;
    end if;
end $$;

comment on function sv__ensure_table() is
    'sv_tools: internal - lazily create pg_temp.sv_session_vars';

/* ----------------------------------------------------------------------- */
/* internal: write implementation                                          */
/* ----------------------------------------------------------------------- */

create function sv__set(
    p_name         text,
    p_type         sv_regtype,
    p_value_int    int              default null,
    p_value_bigint bigint           default null,
    p_value_float  double precision default null,
    p_value_num    numeric          default null,
    p_value_text   text             default null,
    p_value_bool   boolean          default null,
    p_value_json   jsonb            default null,
    p_check_type   boolean          default false
) returns void
language plpgsql
set search_path = @extschema@, pg_temp
as $$
declare
    v_existing sv_regtype;
begin
    perform sv__ensure_table();

    select var_type into v_existing
    from sv_session_vars
    where var_name = p_name;

    if v_existing is not null and v_existing <> p_type then
        if p_check_type then
            raise exception
                'session variable "%" is already %, cannot reassign as %',
                p_name, v_existing, p_type
                using errcode = 'datatype_mismatch';
        end if;
        delete from sv_session_vars where var_name = p_name;
    end if;

    insert into sv_session_vars (
        var_name, var_type,
        var_value_int, var_value_bigint, var_value_float, var_value_num,
        var_value_text, var_value_bool, var_value_json
    ) values (
        p_name, p_type,
        p_value_int, p_value_bigint, p_value_float, p_value_num,
        p_value_text, p_value_bool, p_value_json
    )
    on conflict (var_name) do update
    set var_value_int    = excluded.var_value_int,
        var_value_bigint = excluded.var_value_bigint,
        var_value_float  = excluded.var_value_float,
        var_value_num    = excluded.var_value_num,
        var_value_text   = excluded.var_value_text,
        var_value_bool   = excluded.var_value_bool,
        var_value_json   = excluded.var_value_json,
        updated_at       = now();
end $$;

comment on function sv__set(text, sv_regtype, int, bigint, double precision,
                             numeric, text, boolean, jsonb, boolean) is
    'sv_tools: internal - writes a typed session variable';

/* ----------------------------------------------------------------------- */
/* public: sv_set                                                          */
/* ----------------------------------------------------------------------- */

create function sv_set(p_name text, p_value int,
                       p_check_type boolean default false)
returns int language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'int4'::sv_regtype,
                    p_value_int := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

create function sv_set(p_name text, p_value bigint,
                       p_check_type boolean default false)
returns bigint language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'int8'::sv_regtype,
                    p_value_bigint := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

create function sv_set(p_name text, p_value double precision,
                       p_check_type boolean default false)
returns double precision language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'float8'::sv_regtype,
                    p_value_float := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

create function sv_set(p_name text, p_value numeric,
                       p_check_type boolean default false)
returns numeric language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'numeric'::sv_regtype,
                    p_value_num := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

create function sv_set(p_name text, p_value text,
                       p_check_type boolean default false)
returns text language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'text'::sv_regtype,
                    p_value_text := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

create function sv_set(p_name text, p_value boolean,
                       p_check_type boolean default false)
returns boolean language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'bool'::sv_regtype,
                    p_value_bool := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

create function sv_set(p_name text, p_value jsonb,
                       p_check_type boolean default false)
returns jsonb language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    perform sv__set(p_name, 'jsonb'::sv_regtype,
                    p_value_json := p_value, p_check_type := p_check_type);
    return p_value;
end $$;

/* ----------------------------------------------------------------------- */
/* public: sv_get*                                                         */
/* ----------------------------------------------------------------------- */

create function sv_getint(p_name text) returns int
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result int;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_int into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'int4'::sv_regtype;
    return v_result;
end $$;

create function sv_getbigint(p_name text) returns bigint
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result bigint;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_bigint into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'int8'::sv_regtype;
    return v_result;
end $$;

create function sv_getfloat(p_name text) returns double precision
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result double precision;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_float into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'float8'::sv_regtype;
    return v_result;
end $$;

create function sv_getnum(p_name text) returns numeric
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result numeric;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_num into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'numeric'::sv_regtype;
    return v_result;
end $$;

create function sv_gettext(p_name text) returns text
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result text;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_text into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'text'::sv_regtype;
    return v_result;
end $$;

create function sv_getbool(p_name text) returns boolean
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result boolean;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_bool into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'bool'::sv_regtype;
    return v_result;
end $$;

create function sv_getjson(p_name text) returns jsonb
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare v_result jsonb;
begin
    if to_regclass('pg_temp.sv_session_vars') is null then return null; end if;
    select var_value_json into v_result
    from sv_session_vars
    where var_name = p_name and var_type = 'jsonb'::sv_regtype;
    return v_result;
end $$;

/* ----------------------------------------------------------------------- */
/* public: sv_get (generic, type passed as a hint)                         */
/* ----------------------------------------------------------------------- */

create function sv_get(p_name text, p_type anyelement)
returns setof anyelement
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
declare
    v_col text;
    v_typ sv_regtype;
begin
    v_typ := pg_typeof(p_type)::sv_regtype;

    v_col := case v_typ
        when 'int4'::sv_regtype    then 'var_value_int'
        when 'int8'::sv_regtype    then 'var_value_bigint'
        when 'float8'::sv_regtype  then 'var_value_float'
        when 'numeric'::sv_regtype then 'var_value_num'
        when 'text'::sv_regtype    then 'var_value_text'
        when 'bool'::sv_regtype    then 'var_value_bool'
        when 'jsonb'::sv_regtype   then 'var_value_json'
    end;

    if to_regclass('pg_temp.sv_session_vars') is null then
        return;
    end if;

    return query execute format(
        'select %I from sv_session_vars '
        'where var_name = $1 and var_type = $2::sv_regtype',
        v_col
    ) using p_name, v_typ;
end $$;

/* ----------------------------------------------------------------------- */
/* public: sv_list, sv_unset, sv_reset                                     */
/* ----------------------------------------------------------------------- */

create function sv_list()
returns table (
    var_name   text,
    var_type   sv_regtype,
    var_value  jsonb,
    updated_at timestamptz
)
language plpgsql stable
set search_path = @extschema@, pg_temp as $$
begin
    if to_regclass('pg_temp.sv_session_vars') is null then
        return;
    end if;
    return query
    select
        v.var_name,
        v.var_type,
        case v.var_type
            when 'int4'::sv_regtype    then to_jsonb(v.var_value_int)
            when 'int8'::sv_regtype    then to_jsonb(v.var_value_bigint)
            when 'float8'::sv_regtype  then to_jsonb(v.var_value_float)
            when 'numeric'::sv_regtype then to_jsonb(v.var_value_num)
            when 'text'::sv_regtype    then to_jsonb(v.var_value_text)
            when 'bool'::sv_regtype    then to_jsonb(v.var_value_bool)
            when 'jsonb'::sv_regtype   then v.var_value_json
        end,
        v.updated_at
    from sv_session_vars v
    order by v.var_name;
end $$;

create function sv_unset(p_name text) returns boolean
language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    if to_regclass('pg_temp.sv_session_vars') is null then
        return false;
    end if;
    delete from sv_session_vars where var_name = p_name;
    return found;
end $$;

create function sv_reset() returns void
language plpgsql
set search_path = @extschema@, pg_temp as $$
begin
    if to_regclass('pg_temp.sv_session_vars') is not null then
        delete from sv_session_vars;
    end if;
end $$;


