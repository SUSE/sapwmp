#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "log.h"

#define MAX_FORMAT 128

static int use_syslog;
static int *verbose_p;

void log_init(int *v_p) {
	if (!isatty(STDERR_FILENO)) {
		use_syslog = 1;
	}
	verbose_p = v_p;
}

static inline void vprintlog(int level /*unused*/, const char *fmt, va_list ap) {
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
}

void write_log(int level, const char *fmt, ...) {
	va_list ap;
	if (level >= LOG_DEBUG && !*verbose_p)
		return;

	va_start(ap, fmt);
	if (use_syslog)
		vsyslog(level, fmt, ap);
	else
		vprintlog(level, fmt, ap);
	va_end(ap);
}


void exit_error(int status, int e, const char *fmt, ...) {
	char efmt[MAX_FORMAT];
	const char *pfmt = fmt;
	int r;
	va_list ap;

	/* We don't backup errno since we're exiting anyway. Don't try printing
	 * errno if format creation fails.
	 */
	if (e) {
		r = snprintf(efmt, MAX_FORMAT, "%s: %%m", fmt);
		if (r >= 0 && r < MAX_FORMAT) {
			errno = -e;
			pfmt = efmt;
		}
	}

	va_start(ap, fmt);
	if (use_syslog)
		vsyslog(LOG_ERR, pfmt, ap);
	else
		vprintlog(LOG_ERR, pfmt, ap);
	exit(status);
}

