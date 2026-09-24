SUBDIRS = sv_tools

.PHONY: all install clean $(SUBDIRS)

all:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d all     || exit 1; done

install:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d install || exit 1; done

clean:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d clean   || exit 1; done

