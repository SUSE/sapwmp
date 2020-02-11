#include <assert.h>
#include <linux/limits.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <systemd/sd-bus.h>
#include <unistd.h>

#include "config.h"
#include "log.h"

#define CGROUP_LIMIT_MAX	((uint64_t) -1)
#define MAX_PIDS		16
#define CONF_FILE		"/etc/sysconfig/sapwmp"
#define TASK_COMM_LEN		18	/* +2 for parentheses */
#define UNIT_NAME_LEN		128

#define _cleanup_(x) __attribute__((cleanup(x)))

struct config config;

static inline void freep(void *p) {
	free(*(void **)p);
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
		return r;

	r = sd_bus_message_append(m, "ss", target_unit, "fail");
	if (r < 0)
		return r;

	/* Set properties */

	r = sd_bus_message_open_container(m, 'a', "(sv)");
	if (r < 0)
		return r;

	/* These scopes are for resource control only, processes must be
	 * stopped by other means, only the scope terminates*/
	r = sd_bus_message_append(m, "(sv)", "KillMode", "s", "none");
	if (r < 0)
		return r;

	r = sd_bus_message_append(m, "(sv)", "Slice", "s", target_slice);
	if (r < 0)
		return r;

	/* Parent slice will control actual limit */
	r = sd_bus_message_append(m, "(sv)", "MemoryLow", "t", CGROUP_LIMIT_MAX);
	if (r < 0)
		return r;

	/* PIDs array
	 * container nesting: (sv(a(u)))
	 */
	r = sd_bus_message_open_container(m, 'r', "sv");
	if (r < 0)
		return r;
	r = sd_bus_message_append(m, "s", "PIDs");
	if (r < 0)
		return r;

	r = sd_bus_message_open_container(m, 'v', "au");
	if (r < 0)
		return r;

	r = sd_bus_message_open_container(m, 'a', "u");
	if (r < 0)
		return r;

	for (size_t i = 0; i < n_pids; i++) {
		r = sd_bus_message_append(m, "u", (uint32_t) pids[i]);
	}

	r = sd_bus_message_close_container(m); /* au */
	if (r < 0)
		return r;

	r = sd_bus_message_close_container(m); /* v(au) */
	if (r < 0)
		return r;

	r = sd_bus_message_close_container(m); /* (sv) */
	if (r < 0)
		return r;

	r = sd_bus_message_close_container(m); /* properties array */
	if (r < 0)
		return r;

	/* Aux array */
        r = sd_bus_message_append(m, "a(sa(sv))", 0);
        if (r < 0)
		return r;

        r = sd_bus_call(bus, m, 0, &bus_error, NULL);
	if (r < 0) {
		log_info("DBus call error: %s\n", strerror(sd_bus_error_get_errno(&bus_error)));
	}
	/* ignore reply, i.e. don't wait for the job to finish */
	return r;
}

int read_stat(pid_t pid, pid_t *ppid, char *rcomm) {
	char path[PATH_MAX];
	char *comm = NULL;
	FILE *f;
	int r;

	r = snprintf(path, PATH_MAX, "/proc/%i/stat", pid);
	if (r < 0)
		return r;

	f = fopen(path, "r");
	if (!f)
		return errno;

	r = fscanf(f, "%*d %ms %*c %d", &comm, ppid);
	if (r < 0) {
		r = errno;
		goto final;
	} else if (r < 2) {
		r = -EINVAL;
		goto final;
	}

	/* silently truncate if needed */
	strncpy(rcomm, comm, TASK_COMM_LEN);
	rcomm[TASK_COMM_LEN] = '\0';
	r = 0;
final:
	free(comm);
	fclose(f);
	return r;
}

int collect_pids(pid_t **rpids) {
	int n_pids = 0;
	pid_t pid, ppid;
	char comm[TASK_COMM_LEN + 1]; 
	pid_t *pids;

	assert(rpids);

	pids = malloc(sizeof(pid_t) * MAX_PIDS);
	if (!pids)
		return -ENOMEM;

	pid = getppid();
	while (pid > 1 && n_pids < MAX_PIDS) {
		if (read_stat(pid, &ppid, comm))
			goto err;
		// TODO check actual executables
		// TODO or make this configurable
		if (!strcmp(comm, "(sapstart)") ||
		    !strcmp(comm, "(sapstartsrv)") ||
		    !strcmp(comm, "(fish)")) {
			pids[n_pids++] = pid;
		}
		pid = ppid;
	}

	*rpids = pids;
	return n_pids;

err:
	free(pids);
	return -ESRCH;
}

static int make_scope_name(char *buf) {
	sd_id128_t rnd;
	int r;
        r = sd_id128_randomize(&rnd);
	if (r < 0)
		return r;

	/* -r stands for random
	 * 128 bit should be enough for anyone to avoid collisions */
	r = snprintf(buf, UNIT_NAME_LEN,
		     "wmp-r" SD_ID128_FORMAT_STR ".scope", SD_ID128_FORMAT_VAL(rnd));
	if (r < 0)
		return r;

	return 0;
}

int main(int argc, char *argv[]) {
	_cleanup_(sd_bus_flush_close_unrefp) sd_bus *bus = NULL;
	_cleanup_(freep) pid_t *pids = NULL;
	char unit_name[UNIT_NAME_LEN];
	int n_pids;
	int r;

	r = config_init(&config);
	if (r < 0)
		return ret_log_errno("Failed config init", r);

	r = config_load(&config, CONF_FILE);
	if (r < 0)
		return ret_log_errno("Failed loading config", r);

	n_pids = collect_pids(&pids);
	if (n_pids < 0)
		return ret_log_errno("Failed collecting PIDs", n_pids);
	else if (n_pids == 0)
		return 0;

	r = make_scope_name(unit_name);
	if (r < 0)
		return ret_log_errno("Failed creating scope name", r);

	log_info("Found PIDs: ");
	for (int i = 0; i < n_pids; i++) {
		log_info("%i, ", pids[i]);
	}
	log_info("\n");

	r = sd_bus_open_system(&bus);
	if (r < 0) 
		return ret_log_errno("Failed opening DBus", r);

	r = migrate(bus, unit_name, config.slice, n_pids, pids);
	if (r < 0) {
		log_error("Failed capture into %s/%s", config.slice, unit_name);
		return r;
	}

	log_info("Successful capture into %s/%s", config.slice, unit_name);

	/* skip config_deinit */
	return 0;
}
