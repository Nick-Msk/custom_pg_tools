# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_nothing yet_

## [0.1.0] - 2026-09-24

### Added

* Initial release of `sv_tools`.
* Session variables with seven supported types: `int4`, `int8`, `float8`,
  `numeric`, `text`, `bool`, `jsonb`.
* Domain `sv_regtype` restricting variable types to the supported set.
* `sv_set(name, value [, check_type])` overloads returning the value set.
* Typed getters: `sv_getint`, `sv_getbigint`, `sv_getfloat`, `sv_getnum`,
  `sv_gettext`, `sv_getbool`, `sv_getjson`.
* Generic `sv_get(name, hint)` returning `setof anyelement`.
* Admin helpers: `sv_list()`, `sv_unset(name)`, `sv_reset()`.
* Lazy storage in `pg_temp.sv_session_vars` (`on commit preserve rows`).
* Relocatable extension: installable into any schema chosen by the user.
* Internal functions are pinned with `set search_path = @extschema@, pg_temp`.
* Added `p_check_type` parameter to all `sv_get*` functions; when `true`,
  a missing variable or a type mismatch raises an exception instead of
  silently returning NULL.

[Unreleased]: https://github.com/Nick-Msk/custom_pg_tools/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Nick-Msk/custom_pg_tools/releases/tag/v0.1.0
