#include <assert.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#include "dbus-job.h"
#include "log.h"

/*
 * The code waiting for org.freedesktop.systemd1.Manager.JobRemoved signal is
 * based on systemd's src/shared/bus-wait-for-jobs.c
 */

struct waited_job {
	const char *job;
	char *result;
};

static int match_disconnected(sd_bus_message *m, void *userdata, sd_bus_error *error) {
        assert(m);

        log_info("D-Bus connection terminated while waiting for jobs.");
        sd_bus_close(sd_bus_message_get_bus(m));

        return 0;
}

static int match_job_removed(sd_bus_message *m, void *userdata, sd_bus_error *error) {
	struct waited_job *wj = userdata;
        const char *path, *result;
        int r;

        assert(m);

        r = sd_bus_message_read(m, "uoss", /* id = */ NULL, &path, /* unit = */ NULL, &result);
        if (r < 0) {
		log_error("DBus signal parsing error: %s", strerror(r));
                return 0;
        }

	if (strcmp(path, wj->job))
		return 0;

	wj->result = strdup(result);
	/* best effort upon ENOMEM */
	if (!wj->result)
		wj->result = "";

        return 0;
}

int bus_setup_wait(sd_bus *bus, struct waited_job *wj) {
        int r;

        /* When we are a bus client we match by sender. Direct connections OTOH have no initialized sender
         * field, and hence we ignore the sender then */
        r = sd_bus_add_match(
                        bus,
                        NULL, /* slot removed eventually with sd_bus */
                        "type='signal',"
                        "sender='org.freedesktop.systemd1',"
                        "interface='org.freedesktop.systemd1.Manager',"
                        "member='JobRemoved',"
                        "path='/org/freedesktop/systemd1'",
                        match_job_removed, wj);
        if (r < 0)
                return r;

        r = sd_bus_add_match(
                        bus,
                        NULL, /* slot removed eventually with sd_bus */
                        "type='signal',"
                        "sender='org.freedesktop.DBus.Local',"
                        "interface='org.freedesktop.DBus.Local',"
                        "member='Disconnected'",
                        match_disconnected, wj);
        if (r < 0)
                return r;

        return 0;
}

static int bus_process_wait(sd_bus *bus, struct waited_job *wj) {
        int r;

        for (;;) {
                r = sd_bus_process(bus, NULL);
                if (r < 0)
                        return r;
                if (r > 0 && wj->result) {
			if (wj->result[0] == '\0')
				return -ENOMEM;
			return 0;
		}

                r = sd_bus_wait(bus, UINT64_MAX);
                if (r < 0)
                        return r;
        }
}

int wait_for_job(sd_bus *bus, const char *job) {
	struct waited_job wj = { .job = job };
	int r;

	r = bus_setup_wait(bus, &wj);
	if (r < 0)
		return r;

	r = bus_process_wait(bus, &wj);
	if (r < 0)
		return r;
	log_debug("Job %s finished, result=%s", job, wj.result);
	free(wj.result);
	return r;
}

