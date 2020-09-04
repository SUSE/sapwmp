#!/bin/bash

#  Collects memory data of all cgroups directly beneath /sys/fs/cgroup in syslog.
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

# Walk through cgroups directly beneath root.
line=""
while read cgroup  ; do 
    name="${cgroup#/sys/fs/cgroup/}"
	line="${line}${name} :"
	for param in memory.low memory.current memory.swap.current ; do
	    if [ -e "${cgroup}/${param}" ] ; then
			value=$(< "${cgroup}/${param}")
		else
			value="-"
		fi
		line="${line} ${param}=${value}"
	done 
	line="${line} , "
done < <(find /sys/fs/cgroup -mindepth 1 -maxdepth 1 -type d)

# Write to syslog
logger -p user.info -t "${tag}" "${line% , }"

# Bye.
exit 0
