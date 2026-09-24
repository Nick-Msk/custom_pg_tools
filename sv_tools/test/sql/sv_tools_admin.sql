-- sv_tools regression: admin helpers and edge cases

set client_min_messages = warning;
drop extension if exists sv_tools cascade;
drop schema if exists sv cascade;
reset client_min_messages;

create schema sv;
create extension sv_tools schema sv;
set search_path = sv, public;

-- 1. empty list before anything is set
select count(*) from sv_list();

-- 2. getters return null for missing variables
select sv_getint('nope');
select sv_gettext('nope');
select sv_getbool('nope');
select count(*) from sv_get('nope', null::int);

-- 3. unset on a missing variable
select sv_unset('nope');

-- 4. populate a few and inspect
select sv_set('a', 1);
select sv_set('b', 'two');
select sv_set('c', true);

select var_name, var_type, var_value from sv_list()
where var_name in ('a','b','c')
order by var_name;

-- 5. unset one by one
select sv_unset('a');
select count(*) from sv_list() where var_name in ('a','b','c');

select sv_unset('b');
select sv_unset('c');
select count(*) from sv_list();

-- 6. reset on empty is a no-op
select sv_reset();
select count(*) from sv_list();

