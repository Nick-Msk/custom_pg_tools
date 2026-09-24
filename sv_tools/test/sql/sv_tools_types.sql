-- sv_tools regression: all seven supported types

set client_min_messages = warning;
drop extension if exists sv_tools cascade;
drop schema if exists sv cascade;
reset client_min_messages;

create schema sv;
create extension sv_tools schema sv;
set search_path = sv, public;

-- int4
select sv_set('t_int4', 42::int4);
select sv_getint('t_int4');

-- int8
select sv_set('t_int8', 9223372036854775807::int8);
select sv_getbigint('t_int8');

-- float8
select sv_set('t_float8', 3.14159::float8);
select sv_getfloat('t_float8');

-- numeric
select sv_set('t_numeric', 12345.6789::numeric);
select sv_getnum('t_numeric');

-- text
select sv_set('t_text', 'hello world'::text);
select sv_gettext('t_text');

-- bool
select sv_set('t_bool', true::boolean);
select sv_getbool('t_bool');

-- jsonb
select sv_set('t_jsonb', '{"a":1,"b":[2,3]}'::jsonb);
select sv_getjson('t_jsonb');

-- generic sv_get via type hint
select * from sv_get('t_int4',  null::int4);
select * from sv_get('t_text',  null::text);
select * from sv_get('t_jsonb', null::jsonb);

-- wrong hint returns no rows
select * from sv_get('t_int4', null::text);

-- all seven visible via sv_list
select var_name, var_type, var_value from sv_list()
where var_name like 't\_%'
order by var_name;

