EXTENSION    = sv_tools
DATA         = sv_tools--0.1.sql
PGFILEDESC   = "sv_tools - session variables for PostgreSQL"
REGRESS      = sv_tools sv_tools_types sv_tools_loops sv_tools_admin
REGRESS_OPTS = --inputdir=test

PG_CONFIG ?= pg_config
PGXS      := $(shell $(PG_CONFIG) --pgxs)

include $(PGXS)

