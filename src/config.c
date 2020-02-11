#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "log.h"

#define LINE_LEN		1024

int config_init(struct config *config) {
	config->slice = strdup("sap.slice");
	if (!config->slice)
		return -ENOMEM;

	return 0;
}

/*
 * Remove leading and trailing characters from the set from the given string
 * in-place. Based on systemd strstrip() implementation.
 */
static char *strstrip(char *s, const char *set) {
	char *r, *e;
	r = s + strspn(s, set);

	for (e = strchr(r, '\0'); e > r; e--)
		if (!strchr(set, e[-1]))
			break;
	*e = '\0';
	return r;
}

static char *unquote(char *s) {
	size_t n = strlen(s);
	if (n < 2)
		return s;

	if ((s[0] == '"' && s[n-1] == '"') ||
	    (s[0] == '\'' && s[n-1] == '\'')) {
		s[n-1] = '\0';
		s += 1;
	}

	return s;
}

/*
 * Parse very simple configuration file:
 *   - lines starting with '#' are ignored,
 *   - assignments are in the form [^=]=.*
 *   - rvalue can be optionally single or double quoted.
 */
int config_load(struct config *config, char *filename) {
	char buf[LINE_LEN];
	char *line, *e, *k, *v;
	FILE *f = fopen(filename, "r");
	int r;

	if (!f)
		return -errno;

	while (fgets(buf, LINE_LEN, f)) {
		/* Preprocess line */
		line = strstrip(buf, " \t\r\n");
		if (line[0] == '#')
			continue;
		if (line[0] == '\0')
			continue;

		/* Parse assignment */
		e = strchr(line, '=');
		if (e == NULL) {
			log_info("config: Missing assignment: '%s'\n", line);
			continue;
		}
		e[0] = '\0';
		k = strstrip(line, " \t");
		v = strstrip(e + 1, " \t");
		v = unquote(v);
		v = strdup(v);
		if (v < 0) {
			r = -ENOMEM;
			goto final;
		}

		/* Save configuration */
		if (!strcmp("DEFAULT_SLICE", k)) {
			free(config->slice);
			config->slice = v;
		} else {
			free(v);
			log_info("config: Ignoring key '%s'\n", k);
		}
	}

final:
	fclose(f);
	return r;
}
