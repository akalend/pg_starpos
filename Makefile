MODULES = pg_starpos

EXTENSION = pg_starpos
DATA = pg_starpos--0.1.sql
PGFILEDESC = "pg_starpos - module"


ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/pg_starpos
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif