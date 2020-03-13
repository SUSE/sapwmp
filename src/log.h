#pragma once
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>

#define log_error(...)	_log(LOG_ERR, __VA_ARGS__)
#define log_info(...)	_log(LOG_INFO, __VA_ARGS__)

static inline void _logv(int level /*unused*/, const char *fmt, va_list ap) {
	vfprintf(stderr, fmt, ap);
}

static inline void _log(int level /*unused*/, const char *fmt, ...) {
	va_list ap;

	va_start(ap, fmt);
	_logv(level, fmt, ap);
	va_end(ap);
}

static inline void exit_error(int status, int e, const char *fmt, ...) __attribute__ ((noreturn));
static inline void exit_error(int status, int e, const char *fmt, ...) {
	va_list ap;

	va_start(ap, fmt);
	_logv(LOG_ERR, fmt, ap);
	va_end(ap);

	if (e)
		_log(LOG_ERR, ": %s\n", strerror(-e));
	else
		_log(LOG_ERR, "\n");

	exit(status);
}

