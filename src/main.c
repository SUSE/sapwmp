#include <systemd/sd-bus.h>
#define _cleanup_(x) __attribute__((cleanup(x)))

int main(int argc, char *argv[]) {
        _cleanup_(sd_bus_flush_close_unrefp) sd_bus *bus = NULL;
        _cleanup_(sd_bus_message_unrefp) sd_bus_message *m = NULL, *reply = NULL;
	int r;

        r = sd_bus_open_system(&bus);
        if (r < 0) {
		// TODO log error
		return r;
        }

        r = sd_bus_message_new_method_call(
                        bus,
                        &m,
                        "org.freedesktop.systemd1",
                        "/org/freedesktop/systemd1",
                        "org.freedesktop.systemd1.Manager",
                        "StartTransientUnit");
	return 0;
}
