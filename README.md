# `custom_pg_tools`

A collection of PostgreSQL extensions.

## Extensions

* **sv_tools** — session variables, similar to Oracle package variables.

## Install

```bash
make
sudo make install
```

Then in your database:

```sql
create extension sv_tools;
-- or into a specific schema:
create extension sv_tools schema utils;
```

## `sv_tools`

Session-scoped typed variables. The value and its type live for the duration
of a single connection. The type is fixed on the first `sv_set` call and
cannot be changed without explicitly resetting the variable (or by passing
`p_check_type => true`, which raises an error on type mismatch).

### API

Setters (return the value that was set):

```
sv_set(name, value)              -- int4, int8, float8, numeric, text, bool, jsonb
sv_set(name, value, check_type)  -- raise error if the type differs
```

Getters (return NULL when the variable is missing or the type does not match):

```
sv_getint(name)    -> int
sv_getbigint(name) -> bigint
sv_getfloat(name)  -> double precision
sv_getnum(name)    -> numeric
sv_gettext(name)   -> text
sv_getbool(name)   -> boolean
sv_getjson(name)   -> jsonb
sv_get(name, hint) -> setof anyelement   -- hint is NULL::type
```

Admin:

```
sv_list()          -- list all session variables
sv_unset(name)     -- drop one variable, returns boolean
sv_reset()         -- drop all variables in this session
```

### Example

```sql
select sv_set('user_id', 42);
select sv_getint('user_id');           -- 42
select sv_get('user_id', NULL::int);   -- 42

select sv_set('user_id', 'oops', true); -- error: cannot reassign
select sv_unset('user_id');             -- true
```

### Storage

Data is kept in `pg_temp.sv_session_vars`, a temp table created lazily on the
first `sv_set` call in the session with `on commit preserve rows`. It
disappears automatically when the connection is closed.

## License

PostgreSQL License.

