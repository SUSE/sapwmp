#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <systemd/sd-bus.h>
#include <unistd.h>

#define _cleanup_(x) __attribute__((cleanup(x)))
static inline void freep(void *p) {
	free(*(void **)p);
}

int log_error(int r) {
	fprintf(stderr, "Error: %s\n", strerror(errno));
	return r;
}
void log_info(const char *m) {
	fprintf(stderr, "%s\n", m);
}

int migrate(sd_bus *bus, const char *target_unit, const char *target_slice,
            size_t n_pids, pid_t *pids) {
	_cleanup_(sd_bus_message_unrefp) sd_bus_message *m = NULL;
	_cleanup_(sd_bus_error_free) sd_bus_error bus_error = SD_BUS_ERROR_NULL;
	int r;

	r = sd_bus_message_new_method_call(
		bus,
		&m,
		"org.freedesktop.systemd1",
		"/org/freedesktop/systemd1",
		"org.freedesktop.systemd1.Manager",
		"StartTransientUnit");

	if (r < 0)
		return log_error(r);

	r = sd_bus_message_append(m, "ss", target_unit, "fail");
	if (r < 0)
		return log_error(r);

	r = sd_bus_message_open_container(m, 'a', "(sv)");
	if (r < 0)
		return log_error(r);

	/* Set properties */

	/* These scopes are for resource control only, processes must be
	 * stopped by other means, only the scope terminates*/
	r = sd_bus_message_append(m, "(sv)", "KillMode", "s", "none");
	if (r < 0)
		return log_error(r);

	r = sd_bus_message_append(m, "(sv)", "Slice", "s", target_slice);
	if (r < 0)
		return log_error(r);

	// TODO MemoryLow=infinity

	assert(n_pids == 1); // TODO pass multiple args
	r = sd_bus_message_append(m, "(sv)", "PIDs", "au", 1, (uint32_t) pids[0]);
	if (r < 0)
		return log_error(r);

	r = sd_bus_message_close_container(m);
	if (r < 0)
		return log_error(r);

        r = sd_bus_message_append(m, "a(sa(sv))", 0);
        if (r < 0)
		return log_error(r);

        r = sd_bus_call(bus, m, 0, &bus_error, NULL);
	if (r < 0) {
		fprintf(stderr, "call error: %s\n", strerror(sd_bus_error_get_errno(&bus_error)));
	}
	/* ignore reply, i.e. don't wait for the job to finish */
	return r;
}

int collect_pids(pid_t **rpids) {
	pid_t *pids = malloc(sizeof(pid_t));
	if (!pids)
		return -ENOMEM;

	// TODO traverse all parents
	// TODO check actual executables
	pids[0] = getppid();
	*rpids = pids;
	return 1;
}

int main(int argc, char *argv[]) {
	_cleanup_(sd_bus_flush_close_unrefp) sd_bus *bus = NULL;
	_cleanup_(freep) pid_t *pids = NULL;
	int r;
	char *unit_name, *slice;
	int n_pids;

	n_pids = collect_pids(&pids);
	if (n_pids < 0)
		return log_error(n_pids);
	else if (n_pids == 0)
		return 0;

	// TODO non-colliding name
	unit_name = "instance.scope";
	// TODO load from config
	slice = "sap.slice";

	/* Note: Instead of user checking internally, rely on polkit rules */

	r = sd_bus_open_system(&bus);
	if (r < 0) 
		return log_error(r);

	r = migrate(bus, unit_name, slice, n_pids, pids);
	if (r < 0) 
		return log_error(r);

	log_info("Successful capture");
	return 0;
}
