#pragma once
#include <stdarg.h>
#include <syslog.h>

#define log_error(...)	write_log(LOG_ERR, __VA_ARGS__)
#define log_info(...)	write_log(LOG_INFO, __VA_ARGS__)
#define log_debug(...)	write_log(LOG_DEBUG, __VA_ARGS__)

void log_init(void);
void write_log(int level, const char *fmt, ...);

void exit_error(int status, int e, const char *fmt, ...) __attribute__ ((noreturn));
