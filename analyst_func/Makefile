EXTENSION    = analyst_func
DATA         = analyst_func--0.1.sql
PGFILEDESC   = "analyst_func - analytical functions for PostgreSQL"
REGRESS      = analyst_func
REGRESS_OPTS = --inputdir=test --temp-instance=./tmp_check

PG_CONFIG ?= pg_config
PGXS      := $(shell $(PG_CONFIG) --pgxs)

include $(PGXS)

# ---------------------------------------------------------------------------
# stress test: doubling sizes from 10000 up to hard cap of 1_024_000 rows
#   make stress              # default: 7 doublings (10K .. 1.024M)
#   make stress CNT=4        # 4 doublings: 10K, 20K, 40K, 80K, 160K
# ---------------------------------------------------------------------------

CNT ?= 7
MIN ?= 10000
MAX ?= 1024000

.PHONY: stress
stress:
	@size=$(MIN); \
	for i in $$(seq 0 $(CNT)); do \
		if [ $$size -gt $(MAX) ]; then break; fi; \
		psql -q -d postgres -v ON_ERROR_STOP=1 -v cnt=$$size \
		     -f bench/stress.sql || exit 1; \
		size=$$((size * 2)); \
	done

