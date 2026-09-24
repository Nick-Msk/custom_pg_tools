# `custom_pg_tools`

[![License](https://img.shields.io/badge/license-PostgreSQL-blue.svg)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-336791.svg)](https://www.postgresql.org/)
[![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-experimental-orange.svg)](CHANGELOG.md)
[![Made with SQL](https://img.shields.io/badge/made%20with-SQL%2FPLpgSQL-informational.svg)]()


A collection of small, self-contained PostgreSQL extensions.

## Extensions

| Extension  | Description                                                   | Version |
|------------|---------------------------------------------------------------|---------|
| `sv_tools` | Session variables, similar to Oracle package variables.       | 0.1.0   |

## Install

```bash
make
sudo make install
```

Then in your database:

```sql
create extension sv_tools;
-- or, recommended, into a dedicated schema:
create schema sv;
create extension sv_tools schema sv;
```

See [DISCLAIMER.md](DISCLAIMER.md) before using in production.

## `sv_tools`

Session-scoped typed variables. The value and its type live for the
duration of a single connection. The type is fixed on the first
`sv_set` call and cannot be changed without explicitly resetting the
variable (or by passing `p_check_type => true`, which raises an error
on a type mismatch).

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

Data is kept in `pg_temp.sv_session_vars`, a temp table created lazily
on the first `sv_set` call in the session with `on commit preserve rows`.
It disappears automatically when the connection is closed.

### Recommendations

* Install the extension into a dedicated schema (e.g. `sv`) to keep
  your `public` schema clean.
* Use `set search_path` in the calling session or qualify calls
  explicitly (`sv.sv_set(...)`).
* Do not rely on session variables for anything that must survive a
  reconnect. If a connection pooler reuses connections, remember to
  `sv_reset()` at the start of a logical session.

## Repository layout

```
custom_pg_tools/
├── Makefile
├── README.md
├── CHANGELOG.md
├── DISCLAIMER.md
├── LICENSE
└── sv_tools/
    ├── Makefile
    ├── sv_tools.control
    ├── sv_tools--0.1.sql
    └── test/
        └── smoke.sql
```

Adding a new extension: create a subdirectory, add it to `SUBDIRS` in
the top-level `Makefile`, done.

## License

PostgreSQL License. See [LICENSE](LICENSE).
