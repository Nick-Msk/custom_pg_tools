EXTENSION    = analyst_func
DATA         = analyst_func--0.1.sql
PGFILEDESC   = "analyst_func - analytical functions for PostgreSQL"
REGRESS      = analyst_func
REGRESS_OPTS = --inputdir=test --temp-instance=./tmp_check

PG_CONFIG ?= pg_config
PGXS      := $(shell $(PG_CONFIG) --pgxs)

include $(PGXS)

