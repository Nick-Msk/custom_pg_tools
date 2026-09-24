-- TODO: remove that ----
drop extension if exists sv_tools cascade;
drop schema if exists sv cascade;

create schema if not exists sv;
create extension if not exists sv_tools schema sv;

set search_path = sv, public;
-- END --


-- Basic
select sv_set('x', 42);
select sv_getint('x');

-- Change type
select sv_set('x', 'hello');
select sv_gettext('x');

-- typed NULL
select sv_set('y', NULL::int);
select sv_getint('y');

-- incorrect type
select sv_gettext('y');

-- check_type => true
select sv_set('z', 1, true);
select sv_set('z', 'oops', true);   -- exception

-- print list
select var_name, var_type, var_value sv_list();

-- remove
select sv_unset('x');
select sv_reset();

