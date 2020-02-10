#pragma once
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>

#define log_error(...)	_log(LOG_ERR, __VA_ARGS__)
#define log_info(...)	_log(LOG_INFO, __VA_ARGS__)

static inline void _log(int level /*unused*/, const char *fmt, ...) {
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

static inline int ret_log_errno(const char *msg, int e) {
	log_error("%s: %s\n", strerror(-e));
	return e;
}

