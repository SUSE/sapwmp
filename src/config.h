#pragma once

struct config {
	char *slice;
};

extern int config_init(struct config *);
extern int config_load(struct config *, char *);
