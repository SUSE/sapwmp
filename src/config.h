#pragma once
#include <stdint.h>

#define CGROUP_LIMIT_MAX	((uint64_t) -1)

/* List that was created as a split of a single string */
struct str_list {
	/* NULL terminated array of ptrs into data */
	char **list;
	/* holds string data */
	char *data;
};

struct unit_config {
	char *kill_mode;
	size_t memory_low;
	size_t tasks_max;
};

struct config {
	char *slice;
	struct str_list parent_commands;
	struct unit_config scope_properties;
};

extern int config_init(struct config *);
extern int config_load(struct config *, char *);
extern void config_deinit(struct config *);
