#!/bin/bash

# Collets memory.current of all cgroups directly beneath /sys/fs/cgroup 
# in syslog
#

set -u

tag="wmp_memory_current"

# Exit if cgroup2 is not available or the memeory controller (cgroup2) is missing. 
if [ ! -e /sys/fs/cgroup/cgroup.controllers ] ; then
	logger -p user.error -t "${tag}" "No cgroup2 found! Exiting."
	exit 1
fi
if [[ ! $(< /sys/fs/cgroup/cgroup.subtree_control) =~ memory ]] ; then
	logger -p user.error -t "${tag}" "No memory controller found! Exiting."
	exit 1
fi

# Collect all memory.current of first level.
line=""
while read -r file ; do
	dir="${file%/memory.current}"
	dir="${dir#/sys/fs/cgroup/}"
	line="${line} ${dir}="$(< "${file}")
done < <(find /sys/fs/cgroup -maxdepth 2 -name memory.current)

# Write to syslog
logger -p user.info -t "${tag}" "${line## }"

# Bye.
exit 0
