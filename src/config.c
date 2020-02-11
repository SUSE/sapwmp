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

	config->parent_commands.data = NULL;
	config->parent_commands.list = NULL;

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
 * Split string @s by delimiters @delim and store the structure into list
 * pointed by @rl.
 * New list is allocated and s ownership is passed to @rl.
 */
static int parse_list(struct str_list *rl, char *s, const char *delim) {
	char *c;
	struct str_list l;
	char **pl;
	int n = 1;

	l.data = s;
	s = strstrip(s, delim);
	for (c = s; *c; c++)
		if (strchr(delim, *c))
			n++;

	/* Add one for NULL terminated list */
	l.list = calloc(n + 1, sizeof(char *));
	if (!l.list)
		return -ENOMEM;

	pl = l.list;
	while ((c = strsep(&s, delim))) {
		*(pl++) = c;
	}

	free(rl->list);
	free(rl->data);
	rl->data = l.data;
	rl->list = l.list;
	return 0;
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
		} else if (!strcmp("PARENT_COMMANDS", k)) {
			if (parse_list(&config->parent_commands, v, ",")) {
				free(v);
				log_info("config: Parsing failed for '%s'\n", k);
				continue;
			}
		} else {
			free(v);
			log_info("config: Ignoring key '%s'\n", k);
		}
	}

final:
	fclose(f);
	return r;
}
