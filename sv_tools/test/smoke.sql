-- sv_tools smoke test
-- usage: psql -d yourdb -f smoke.sql

\set ON_ERROR_STOP off

create extension if not exists sv_tools;

-- basic set/get
select sv_set('x', 42);
select sv_getint('x') as expect_42;

-- reassign to another type: without check - overwrite
select sv_set('x', 'hello');
select sv_gettext('x') as expect_hello;

-- generic get
select * from sv_get('x', NULL::text) as t(v);

-- null value preserved with explicit type
select sv_set('y', NULL::int);
select sv_getint('y') as expect_null;

-- wrong type read returns null
select sv_gettext('y') as expect_null_too;

-- check_type => true forbids type change
select sv_set('z', 1, true);
select sv_set('z', 'oops', true);   -- error expected

-- listing
select sv_list();

-- unset
select sv_unset('x');
select sv_list();

-- reset
select sv_reset();
select sv_list();

