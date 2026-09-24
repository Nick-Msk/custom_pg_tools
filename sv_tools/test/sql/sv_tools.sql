-- sv_tools regression: basic single-variable behaviour

set client_min_messages = warning;
drop extension if exists sv_tools cascade;
drop schema if exists sv cascade;
reset client_min_messages;

create schema sv;
create extension sv_tools schema sv;
set search_path = sv, public;

-- 1. set/get int
select sv_set('x', 42);
select sv_getint('x');

-- 2. overwrite with another type (no check)
select sv_set('x', 'hello');
select sv_gettext('x');

-- 3. null value keeps its type
select sv_set('y', null::int);
select sv_getint('y');

-- 4. wrong type read yields null
select sv_gettext('y');

-- 5. check_type => true forbids reassignment
select sv_set('z', 1, true);
select sv_set('z', 'oops', true);   -- error expected

-- 6. unset return values
select sv_unset('z');   -- true
select sv_unset('z');   -- false, already gone

