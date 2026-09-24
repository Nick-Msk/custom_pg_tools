SUBDIRS = sv_tools

.PHONY: all install clean $(SUBDIRS)

all:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d all     || exit 1; done

install:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d install || exit 1; done

clean:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d clean   || exit 1; done

installcheck:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d installcheck || exit 1; done

installcheck-clean:
	psql -d postgres -c "drop database if exists contrib_regression" || true
	$(MAKE) installcheck

