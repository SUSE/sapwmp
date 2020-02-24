sapwmplibexecdir=$(libexecdir)/sapwmp

sapwmplibexec_PROGRAMS = sapwmp-capture
sapwmp_capture_CFLAGS = \
	$(LIBSYSTEMD_CGLAGS)
sapwmp_capture_LDADD = \
	$(LIBSYSTEMD_LIBS)
sapwmp_capture_SOURCES = src/main.c src/config.c
