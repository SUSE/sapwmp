#pragma once

/* List that was created as a split of a single string */
struct str_list {
	/* NULL terminated array of ptrs into data */
	char **list;
	/* holds string data */
	char *data;
};

struct config {
	char *slice;
	struct str_list parent_commands;
};

extern int config_init(struct config *);
extern int config_load(struct config *, char *);
