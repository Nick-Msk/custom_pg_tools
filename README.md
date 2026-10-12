# `custom_pg_tools`

[![License](https://img.shields.io/badge/license-PostgreSQL-blue.svg)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-336791.svg)](https://www.postgresql.org/)
[![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-experimental-orange.svg)](CHANGELOG.md)
[![Made with SQL](https://img.shields.io/badge/made%20with-SQL%2FPLpgSQL-informational.svg)]()
[![CI](https://github.com/Nick-Msk/custom_pg_tools/actions/workflows/ci.yml/badge.svg)](https://github.com/Nick-Msk/custom_pg_tools/actions/workflows/ci.yml)

A collection of small, self-contained PostgreSQL extensions.

## Extensions

| Extension  | Description                                                   | Version |
|------------|---------------------------------------------------------------|---------|
| `sv_tools` | Session variables, similar to Oracle package variables.       | 0.1.0   |
| `analyst_func` | Analytical functions, starting with `median()`.           | 0.1.0   |

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

Typed getters (return NULL when the variable is missing or the type
does not match, unless `check_type` is `true`):

```
sv_getint(name [, check_type])    -> int
sv_getbigint(name [, check_type]) -> bigint
sv_getfloat(name [, check_type])  -> double precision
sv_getnum(name [, check_type])    -> numeric
sv_gettext(name [, check_type])   -> text
sv_getbool(name [, check_type])   -> boolean
sv_getjson(name [, check_type])   -> jsonb
```

Generic getter (type is passed as a hint, `NULL::type`):

```
sv_get(name, hint [, check_type]) -> setof anyelement
```

Admin helpers (always tolerant to an empty session):

```
sv_list()          -- list all session variables
sv_unset(name)     -- drop one variable, returns boolean
sv_reset()         -- drop all variables in this session
```

### Behaviour matrix for getters

| Situation                              | `check_type = false` (default) | `check_type = true` |
|----------------------------------------|--------------------------------|---------------------|
| Variable exists, value present         | return value                   | return value        |
| Variable exists, value is NULL         | NULL                           | NULL                |
| Variable missing or type does not match| NULL (silent)                  | `ERROR`             |
| Temp table does not exist yet          | `ERROR: relation ... does not exist` | same |

Calling a getter without a prior `sv_set` in the session is considered a
programming error and fails. Admin helpers (`sv_list`, `sv_unset`,
`sv_reset`) keep working on an empty session and return empty results.

### Example

```sql
select sv_set('user_id', 42);
select sv_getint('user_id');               -- 42
select sv_get('user_id', NULL::int);       -- 42

select sv_gettext('user_id');              -- NULL, silent
select sv_gettext('user_id', true);        -- ERROR: not text

select sv_set('user_id', 'oops', true);    -- ERROR: cannot reassign
select sv_unset('user_id');                -- true
```

### Storage

Session variables live in a temporary table called
`pg_temp.sv_session_vars`, created lazily on the first `sv_set` call in
a session with `on commit preserve rows`. It disappears automatically
when the connection closes.

The temp table lives in the session-local schema `pg_temp_N` (the alias
`pg_temp` works in SQL but **not** in psql meta-commands). To inspect it
from `psql`:

```
\dt pg_temp_*.*
```

```
                                          List of tables
  Schema   |      Name       | Type  | Owner  | Persistence | Access method | Size  | Description
-----------+-----------------+-------+--------+-------------+---------------+-------+-------------
 pg_temp_6 | sv_session_vars | table | skelet | temporary   | heap          | 16 kB |
(1 row)
```

Or, more conveniently, use the extension's own helper:

```sql
select * from sv.sv_list();
```

Note that the temp table lives in `pg_temp_N`, **not** in the schema you
installed the extension into. `\dt <your_schema>.*` will only show the
functions and the domain — the data itself is in the session-local
schema.

### Session lifetime

The temp table exists only in the session that created it. If you open
a new `psql` connection, the table is gone:

```sql
-- session 1
select sv.sv_set('x', 1);
select sv.sv_getint('x');       -- 1
\q

-- session 2
select sv.sv_list();            -- empty
select sv.sv_getint('x');       -- ERROR: relation "sv_session_vars" does not exist
```

This is by design: variables are session-scoped and are not meant to
survive reconnects. If you use a connection pooler, remember to call
`sv_reset()` at the start of each logical session.

### Recommendations

* Install the extension into a dedicated schema (e.g. `sv`) to keep
  your `public` schema clean.
* Use `set search_path` in the calling session or qualify calls
  explicitly (`sv.sv_set(...)`).
* Do not rely on session variables for anything that must survive a
  reconnect. If a connection pooler reuses connections, remember to
  `sv_reset()` at the start of a logical session.
* Install `sv_tools` **once per database**. See
  [DISCLAIMER.md](DISCLAIMER.md#one-installation-per-database) for the
  reasoning.
* The schema is fixed at `create extension sv_tools schema <name>` time
  and cannot be changed later with `alter extension ... set schema`.

## `analyst_func`

Analytical functions that PostgreSQL does not ship in core.

### `median()`

Exact median for `numeric`. Unlike `percentile_cont`, which works only
on `double precision` and `interval`, this aggregate returns `numeric`
and preserves precision.

```sql
select median(x) from (values (1), (2), (3), (4)) as t(x);
-- 2.5

select median(x) from (values (1.1), (2.2), (3.3), (4.4)) as t(x);
-- 2.75   (no float drift)
```

Works as an aggregate and as a window function. NULL values are
ignored. Empty input, all-NULL input, and empty window frames return
NULL. Moving window frames (`rows between ... and ...`) are supported
via an inverse transition function that advances an internal skip
counter instead of copying the state.

### Installation

```sql
create schema af;
create extension analyst_func schema af;
```

### Performance

The plain (non-moving) implementation accumulates the whole group in
an array and sorts it once in the final function. Array append copies
the array on every step, so the transition function has **O(n²)**
behaviour in the number of rows per group.

Approximate timings on a single-modern-core machine:

| rows per group | full median |
|----------------|-------------|
| 10 000         | 0.12 s      |
| 40 000         | 1.8 s       |
| 160 000        | 27 s        |
| 640 000        | 59 s        |

For groups of 10 000–50 000 rows the implementation is practical. For
millions of rows per group, use `percentile_cont(0.5)` if `double
precision` precision is acceptable, or plan a C extension with an
`internal`-typed state.

Moving window frames use a skip counter and are **O(1)** per removed
row, so they behave better than the plain path.

### Benchmark

```
make stress CNT=6        # doubles from 10K up to 640K
make stress CNT=7        # up to 1.024M
```

Output format: `cnt|method|us`.

## Comparison with `pg_variables`

[`pg_variables`](https://github.com/postgrespro/pg_variables) by Postgres
Professional solves a similar problem — session-scoped variables — and is
more feature-rich. `sv_tools` takes a different trade-off: minimalism at
the cost of features.

| | `pg_variables` | `sv_tools` |
|---|---|---|
| Implementation language | C | SQL / PL/pgSQL |
| Build requirements | C compiler, `make`, headers | none |
| Test requirements | `make installcheck`, Valgrind for memory checks | `make installcheck` |
| Ships as | `.so` shared library + SQL | SQL only |
| Supported types | scalar, `record`, `array` | 7 scalar types (`int4`, `int8`, `float8`, `numeric`, `text`, `bool`, `jsonb`) |
| Transactional variables | yes (opt-in via `is_transactional` flag) | no |
| Record variables | yes (`pgv_insert`, `pgv_get` on records) | no |
| Array variables | yes | no |
| Installation | `make USE_PGXS=1 && make USE_PGXS=1 install` | `make && make install` |
| Runtime dependency | compiled `.so` matching PG version and ABI | none |
| Lines of C code | substantial | 0 |
| Lines of SQL | a wrapper around C | ~400 |

### When to pick which

**Pick `pg_variables` if you need:**

* record or array variables,
* transactional variables that respect `begin` / `commit` / `rollback`,
* a battle-tested extension maintained by Postgres Professional.

**Pick `sv_tools` if you:**

* want zero build toolchain — no compiler, no headers, no `.so`,
* prefer to read and modify the entire implementation in an afternoon,
* only need scalar variables of common types,
* want to install by simply running `psql -f sv_tools--0.1.sql`.

`sv_tools` is not a replacement for `pg_variables`. It is a smaller,
simpler alternative for cases where the full feature set of
`pg_variables` is overkill and the C toolchain is a burden.

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
        ├── sql/
        │   ├── sv_tools.sql
        │   ├── sv_tools_types.sql
        │   ├── sv_tools_loops.sql
        │   └── sv_tools_admin.sql
        └── expected/
            ├── sv_tools.out
            ├── sv_tools_types.out
            ├── sv_tools_loops.out
            └── sv_tools_admin.out
```

Adding a new extension: create a subdirectory, add it to `SUBDIRS` in
the top-level `Makefile`, done.

## Tests

Regression tests use the standard `pg_regress` infrastructure shipped
with PostgreSQL. The CI pipeline runs tests on PostgreSQL 14 through 18
using `actions/checkout@v5` and `--temp-instance` for isolated testing.

```bash
cd sv_tools
make install
make installcheck
```

Expected output:

```
ok 1     - sv_tools
ok 2     - sv_tools_types
ok 3     - sv_tools_loops
ok 4     - sv_tools_admin
1..4
# All 4 tests passed.
```

## License

PostgreSQL License. See [LICENSE](LICENSE).

