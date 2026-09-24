# Disclaimer

## No warranty

This software is provided **"as is"**, without warranty of any kind,
express or implied, including but not limited to the warranties of
merchantability, fitness for a particular purpose, and non-infringement.
In no event shall the authors or copyright holders be liable for any
claim, damages, or other liability, whether in an action of contract,
tort, or otherwise, arising from, out of, or in connection with the
software or the use or other dealings in the software.

## Not production-hardened

The extensions in this repository are **experimental**. They have not
been subjected to the same level of testing, review, and hardening as
the PostgreSQL core. Before deploying to production:

* Review the SQL source end to end.
* Run your own tests against your PostgreSQL version, extensions, and
  workload.
* Take a backup.
* Test in a staging environment first.

## Schema isolation and `search_path`

Install the extensions into a **dedicated schema** rather than `public`
or `pg_catalog`. This is not a formality: it protects you against name
collisions with user objects and third-party extensions, and it makes
the `search_path` of your application sessions predictable.

```sql
create schema sv;
create extension sv_tools schema sv;

-- in the application session:
set search_path = sv, public;
-- or qualify explicitly:
select sv.sv_set('x', 1);
```

### Why `search_path` matters

* **Shadowing.** If your schema comes before `public` in `search_path`,
  a malicious or careless object with the same name in an earlier schema
  can shadow the intended function. Always control `search_path` at the
  session or role level.
* **Untrusted users.** If untrusted users can create objects in a schema
  that appears in `search_path`, they can hijack unqualified calls. Do
  not put such schemas in the search path of privileged sessions.
* **Session variables.** `sv_tools` stores data in a temp table
  (`pg_temp.sv_session_vars`). Temp schemas are session-local, but the
  functions that access them live in the extension schema — hence the
  internal `set search_path = @extschema@, pg_temp` guard.

## Session variables and connection pooling

Session variables are tied to a **physical connection**. If your
application uses a connection pooler (PgBouncer, Odyssey, pgpool-II),
the next logical client may inherit variables from the previous one.
To avoid surprises:

* Call `sv_reset()` at the start of each logical session.
* Or configure the pooler to use **session pooling** mode, not
  transaction or statement pooling.
* Never store secrets (passwords, tokens) in session variables longer
  than strictly necessary.

## Data loss

All session variables are lost when the connection closes, and are not
replicated, not backed up, and not visible to other sessions. Do not
use them for durable state.

## Trademarks

PostgreSQL is a registered trademark of the PostgreSQL Community
Association. Oracle is a registered trademark of Oracle Corporation.
Any references to Oracle are for descriptive purposes only and do not
imply affiliation or endorsement.

