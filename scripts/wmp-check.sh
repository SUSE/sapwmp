#!/bin/bash
# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 3 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
# Author: Sören Schmidt <soeren.schmidt@suse.com>
#
# This tool checks if WMP is set up correctly. 
#
# exit codes:       0   All checks ok. WMP has been set up correctly.
#                   1   Some warnings occured. WMP should work, but better check manually.
#                   2   Some errors occured. WMP will not work.
#                   3   Wrong parameters given to the tool on commandline.
#
# Changelog:
#
# 12.10.2020  v1.0      First release
# 13.10.2020  v1.0.1    Added check of memory.low=max for SAP.slice children
# 03.11.2020  v1.0.2    Fixed wrong permissions in capture program test
#                       Fixed OS version detection 
#                       Fixed issues with MemoryLow test
#                       Fixed issues with profile detection
#                       Fixed issue with cgroup detection  
#                       Added cgroup v1 detection
# 09.12.2020  v1.0.3    Optimized pattern for profile detection
# 14.12.2020  v1.1.0    cgroup2 mount detection fixed
#                       Further optimized pattern for profile detection  
#                       Detection of SAP instances reworked a bit
# 09.04.2021  v1.1.1    Add colorful output
#                       Check generated grub2 configure
#                       Enable support for SLE15SP0/SP1
#                       Support RPM package version check
# 19.04.2021  v1.1.2    Remove sapstartsrv from process tree to capture
#                       Enable support for SLE15SP3
# 1.11.2021             Enable support for SLE15SP4
# 2.14.2022   v1.1.3    Adjust checker for SAP systemd integration

version="1.1.3"

# We use these global arrays through out the program:
#
# package_version                -  contains package version (string)
# cgroup_unified                 -  contains if unified cgroup hierarchy is configured and active
# capture_state                  -  contains permission and ownership of the capturer program
# SAP_profile_path               -  contains profile path of SAP instances 
# SAP_profile_wmp_entry          -  contains WMP entry in SAP profiles
# memory_info                    -  contains system memory information 
# SAP_slice_data                 -  contains information about SAP.slice
# SAP_instance_processes         -  contains pids of that instance
# SAP_processes_outside_cgroup   -  contains pids of that instance which are not in SAP.slice
# unit_state_active              -  contains systemd unit state (systemctl is-active) 
# unit_state_enabled             -  contains systemd unit state (systemctl is-enabled) 
# swapaccounting_state           -  contains if cgroup swap accounting is configured and active
declare -A package_version required_pkgs cgroup_unified capture_state memory_info SAP_profile_path SAP_profile_wmp_entry SAP_slice_data SAP_instance_processes SAP_processes_outside_cgroup unit_state_active unit_state_enabled swapaccounting_state

# Required packages list
# examples:
#		[{name}]="{version}-{release}"
#		[{name}]="{version}"
#		[{name}]=""
required_pkgs=(
    [sapwmp]=""
    [systemd]="234-24.67.1"
)

# Some counters.
SAP_processes=0
SAP_processes_outside=0

# Colorful output, set to 'false' to disable.
# Disable color automatically if we run in a pipe
ENABLE_COLORIZE=true
[ -t 1 ] || ENABLE_COLORIZE=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
GRAY='\033[0;37m'
RESET='\033[0m'

if [[ $ENABLE_COLORIZE = false ]];then
    unset RED GREEN YELLOW GRAY RESET
fi

function header() { 
    local len=${#1}
    echo -e "\n${1}"
    printf '=%.s' $(eval "echo {1.."$((${len}))"}")
    echo
}

function print_ok() {
    local text="  ${@}"
    echo -e "[ ${GREEN}OK${RESET} ]${text}"
}

function print_fail() {
    local text="${1}"
    local hint="${2}"
    echo -e "[${RED}FAIL${RESET}]  ${text}\n        -> ${hint}"
}

function print_warn() {
    local text="  ${@}"
    echo -e "[${YELLOW}WARN${RESET}]${text}"
}

function print_note() {
    local text="  ${@}"
    echo -e "[${GRAY}NOTE${RESET}]${text}"
}

function version_lt() {
    # Params:   VERSION1 VERSION2
    # Output:   -
    # Exitcode: boolean result
    #
    # Compare the two RPM package version
	#
    # Requires: -
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1";
}

function get_package_versions() {
    # Params:   PACKAGE...
    # Output:   -
    # Exitcode: -
    #
    # Determines package version as string for each PACKAGE.
    # Not installed packages will have an empty string as version.
    #
    # The function updates the associative array "package_version".
    #
    # Requires:-

    local package version release
    for package in "${@}" ; do
        if version=$(rpm -q --qf '%{version}' "${package}" 2>&1) ; then
            if release=$(rpm -q --qf '%{release}' "${package}" 2>&1) ; then
                package_version["${package}"]=${version}-${release}
            else
                package_version["${package}"]=${version}
            fi
        else
            package_version["${package}"]=''
        fi
    done
}

function get_cgroup_state() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Determines if cgroup2 unified hierarchy is configured and active.
    # It also checks for remaining cgroup v1 controllers.
    #
    # The function updates the associative array "cgroup_unified".
    #
    # Requires: -

    if [[ $(grep 'GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub) =~ systemd.unified_cgroup_hierarchy=(1|true|yes) ]] ; then
        if [[ $(grep '[[:space:]]linux[[:space:]]' /boot/grub2/grub.cfg) =~ systemd.unified_cgroup_hierarchy=(1|true|yes) ]] ; then
            cgroup_unified['configured']='yes'
        else
            cgroup_unified['configured']='needupdate'
        fi
    else
        cgroup_unified['configured']='no'
    fi
    if egrep -q '^cgroup.? /sys/fs/cgroup cgroup2' /proc/mounts ; then
        cgroup_unified['active']='yes'
    else
        cgroup_unified['active']='no'
    fi
    if cut -d ' ' -f 3 /proc/mounts | grep -q '^cgroup$' ; then
        cgroup_unified['v1-controllers']=$(grep ' cgroup ' /proc/mounts | cut -d ' ' -f 4 | tr ',' '\n' | sort -u | egrep '^(cpu|cpuacct|cpuset|memory|devices|freezer|net_cls|blkio|perf_event|net_prio|hugetlb|pids|rdma)$' | tr '\n' ' ')  # not very beautiful...
    else
        cgroup_unified['v1-controllers']='no'
    fi
}

function get_capture_state() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Determines ownership and permissions of the capture program.
    #
    # The function updates the associative array "capture_state".
    #
    # Requires: -

    capture_state['name']='/usr/lib/sapwmp/sapwmp-capture'

    if [ -e "${capture_state['name']}" ] ; then
        capture_state['exists']='yes'
        read capture_state['permissions'] capture_state['ownership'] < <(stat -c '%a %U:%G' "${capture_state['name']}" 2> /dev/null) 
    else
        capture_state['exists']='no'
    fi
}

function get_SAP_profile_data() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Collcets data of SAP instance profiles.
    #
    # The function updates the associative arrays "SAP_profile_path" and "SAP_profile_wmp_entry".
    #
    # Requires: capture_state['name'] set by get_capture_state()

    local capture_pattern path profile 

    capture_pattern="^[[:space:]]*Execute_[[:digit:]]+[[:space:]]*=[[:space:]]*local[[:space:]]+${capture_state['name']}"

    for path in /usr/sap/*/SYS/profile/* ; do 
        [[ "${path}" =~ /[[:alnum:]]+_[[:alnum:]]+_[[:alnum:]-]+$ ]] || continue
        profile="${path##*/}"
        SAP_profile_path["${profile}"]="${path}"
        SAP_profile_wmp_entry["${profile}"]=$(egrep "${capture_pattern}" "${path}")
        SAP_profile_wmp_entry["${profile}"]="${SAP_profile_wmp_entry[${profile}]:=-}"
    done
}

function get_system_meminfo() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Collects memory infromation from /proc/meminfo.
    #
    # The function updates the associative array "memory_info".
    #
    # Requires: -

    local line param value

    while read line ; do
        param="${line%%:*}"
        value="${line##*:}"
        value="${value// /}"  # remove spaces
        [ "${value: -2}" == 'kB' ] && value=$(( ${value%%??} * 1024 )) # cut off unit and convert
        memory_info["${param}"]="${value}"
    done < /proc/meminfo 
}

function get_SAP_slice_data() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Determines existence, state and memory information of the SAP slice.
    #
    # The function updates the associative array "SAP_slice_data".
    #
    # Requires: -

    local path error

    SAP_slice_data['name']='SAP.slice'

    if systemctl cat "${SAP_slice_data['name']}" > /dev/null 2>&1 ; then
        SAP_slice_data['exists']='yes'
        SAP_slice_data['state_active']=$(systemctl is-active "${SAP_slice_data['name']}" 2> /dev/null)
        SAP_slice_data['state_enabled']=$(systemctl is-enabled "${SAP_slice_data['name']}" 2> /dev/null)
        SAP_slice_data['MemoryLow']=$(systemctl show -p MemoryLow --value "${SAP_slice_data['name']}" 2> /dev/null)
        SAP_slice_data['memory.low']=$(cat "/sys/fs/cgroup/${SAP_slice_data['name']}/memory.low" 2>/dev/null)
        SAP_slice_data['memory.low']=${SAP_slice_data['memory.low']:=0}
        SAP_slice_data['memory.current']=$(cat "/sys/fs/cgroup/${SAP_slice_data['name']}/memory.current" 2>/dev/null)
        SAP_slice_data['memory.current']=${SAP_slice_data['memory.current']:=0}
        SAP_slice_data['unprotect_list']=${SAP_slice_data['unprotect_list']:=''}

        error=0
        while read path ; do
            if [ ! -e "${path}/memory.low" ] || [ "$(< ${path}/memory.low)" != 'max' ]; then
                if [ ${#SAP_slice_data['unprotect_list']} -ne 0 ]; then
                    SAP_slice_data['unprotect_list']+=" ${path##*/}"
                else
                    SAP_slice_data['unprotect_list']+="${path##*/}"
                fi
                ((error++))
            fi
        done < <(find "/sys/fs/cgroup/${SAP_slice_data['name']}/" -mindepth 1 -type d)

        if [ ${error} -ne 0 ] ; then
            SAP_slice_data['memory_low_children']='false'
        else
            SAP_slice_data['memory_low_children']='ok'
        fi

    else
        SAP_slice_data['exists']='no'
    fi
}

function get_SAP_process_data() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Determines all processes of SAP instances and the ones outside SAP.slice.
    #
    # The function updates the associative arrays "SAP_instance_processes" and "SAP_processes_outside_cgroup"
    # as well as the variables "SAP_processes" and "SAP_processes_outside".
    #
    # Requires: -

    local pd line pid comm state ppid proc_ppid proc_comm sapstart_pids parent sapstart_list tmp_pid cmdline component profile_name instance cgroup
    declare -A proc_ppid proc_comm sapstart_pids 

    # Collect current process information and create a list of sapstart/sapstartsrv processes.
    for pd in /proc/[0-9]*/stat ; do 
        [ -e "${pd}" ] || continue  # process has died meanwhile
        read line  < "${pd}"

        # Split line apart (comm can contain spaces, so the brackets have to be used as separator). 
        pid="${line%% *}" ; line="${line#* }"
        comm="${line%%)*}" ; comm="${comm:1}"; line="${line#*) }"
        state="${line%% *}" ; line="${line#* }"
        ppid="${line%% *}" ; line="${line#* }"
        proc_ppid[${pid}]=${ppid} 
        proc_comm[${pid}]="${comm}" 
        [[ "${comm}" =~ ^sapstart$ ]] && sapstart_pids[${pid}]="${pid}"
    done

    # Go through all pids and walk back through it's parents. and identify children of sapstart.
    sapstart_list=" ${!sapstart_pids[@]} "  # all sapstart processes as string (leading and trailling spaces are important!)
    for pid in "${!proc_ppid[@]}" ; do
        parent=${proc_ppid[${pid}]}
        while [ ${parent} -gt 1 ] ; do
            tmp_pid=${parent}
            parent=${proc_ppid[${tmp_pid}]}
            [[ "${sapstart_list}" =~ \ ${tmp_pid}\  ]] && sapstart_pids[${tmp_pid}]="${sapstart_pids[${tmp_pid}]} ${pid}"
        done
    done

    # Aggregate proccesses per SAP instance.
    for pid in "${!sapstart_pids[@]}" ; do 
        [ -e "/proc/${pid}/cmdline" ] || continue
        cmdline=$( tr '\0' ' ' < /proc/${pid}/cmdline)
        for component in ${cmdline} ; do 
            [ "${component:0:3}" == "pf=" ] && profile_name="${component##*/}" 
        done
        [ -z "${profile_name}" ] && continue   # profile is required
        [ "${profile_name}" == 'host_profile' ] && continue  # HostAgent is not covered by WMP 

        SAP_instance_processes[${profile_name}]="${SAP_instance_processes[${profile_name}]} ${sapstart_pids[${pid}]}"
    done

    # Collect all instance processes which are not in SAP.slice.
    SAP_processes=0
    for instance in "${!SAP_instance_processes[@]}" ; do
        for pid in ${SAP_instance_processes[${instance}]} ; do
            ((SAP_processes++))
            [ -e "/proc/${pid}/cgroup" ] || continue
            if ! grep -q '^0::/SAP.slice/' "/proc/${pid}/cgroup" ; then
                SAP_processes_outside_cgroup[${instance}]="${SAP_processes_outside_cgroup[${instance}]} ${pid}"
                ((SAP_processes_outside++))
            fi
        done
    done

}

function get_unit_states() {
    # Params:   UNIT...
    # Output:   -
    # Exitcode: -
    #
    # Determines the state (is-active/is-enabled) for each UNIT.
    # A missing state is reported as "missing".
    #
    # The function updates the associative arrays "unit_state_active" and "unit_state_enabled".
    #
    # Requires: -

    local unit state_active state_enabled
    for unit in "${@}" ; do
        state_active=$(systemctl is-active "${unit}" 2> /dev/null)
        state_enabled=$(systemctl is-enabled "${unit}" 2> /dev/null)
        unit_state_active["${unit}"]=${state_active:-missing}
        unit_state_enabled["${unit}"]=${state_enabled:-missing}
    done
}

function get_swapaccounting_state() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Determines if swapaccounting is configured and active.
    #
    # The function updates the associative array "swapaccounting_state".
    #
    # Requires: -

    if [[ $(grep 'GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub) =~ swapaccount=(1|true|yes) ]] ; then
        swapaccounting_state['configured']='yes'
    else
        swapaccounting_state['configured']='no'
    fi
    if [ -e /sys/fs/cgroup/init.scope/memory.swap.current ] ; then
        swapaccounting_state['active']='yes'
    else
        swapaccounting_state['active']='no'
    fi
}

function check_pkg_version () {
    # Params:   -
    # Output:   -
    # Exitcode: 2 if packages not installed properly
    #
    # Checks if required packages are installed correctly.
    #
    # Requires: -
    local err_msg=""

    for key in $(echo ${!required_pkgs[*]})
    do
        [[ -z ${package_version[$key]} ]] && err_msg=${err_msg}"Package '$key' not installed.\n" && continue

        [[ -z ${required_pkgs[$key]} ]] && continue

        if version_lt ${package_version[$key]} ${required_pkgs[$key]}; then
            err_msg=${err_msg}"Package '$key(${package_version[$key]})' need upgrade to at least '$key(${required_pkgs[$key]})'.\n"
        fi
    done

    if [ ! -z "$err_msg" ]; then
        print_fail "$err_msg" "Please use zypper to install/upgrade."
        exit 2
    fi
}

function collect_data() {
    # Params:   -
    # Output:   -
    # Exitcode: -
    #
    # Calls various functions to collect data.
    #
    # Requires: get_package_versions()
    #           get_cgroup_state()
    #           get_capture_state()
    #           get_system_meminfo()
    #           get_SAP_slice_data()
    #           get_SAP_profile_data()
    #           get_SAP_process_data()
    #           get_unit_states()
    #           get_swapaccounting_state()

    # Collect data about some packages.
    for pkg in $(echo ${!required_pkgs[*]})
    do
        get_package_versions $pkg
    done

    # Collect cgroup status.
    get_cgroup_state

    # Collect ownership and permissions of capture program.
    get_capture_state

    # Collect system memory information.
    get_system_meminfo

    # Collect data about SAP.slice.
    get_SAP_slice_data

    # Collect SAP instance profile data.
    get_SAP_profile_data

    # Collect SAP process information.
    get_SAP_process_data

    # Collect states of some systemd units.
    get_unit_states wmp-sample-memory.timer

    # Collect swap accounting status.
    get_swapaccounting_state
}


function check_wmp() {
    # Checks if WMP is installed correctly.
    #
    # - sap_wmp package should be installed
    # - cgroups2 have to be active and enabled via GRUB 
    # - cgroup v1 controllers should not be active
    # - capture program has to have the correct ownership and permissions
    # - Instance profile has been altered 
    # - Instance processes are in SAP.slice
    # - SAP.slice is configured and active (MemoryLow=/memory.low are set) 
    # - MemoryLow should have a sane value
    # - Timer unit to monitor cgroup data has been set.


    local fails=0 warnings=0 tuned_used version_tag page_size

    # We can stop, if required packages are not installed properly.
    check_pkg_version

    # Cgroup2 has to be configured and mounted in the unified hierarchy.
    case "${cgroup_unified['active']}" in
        yes)
            case "${cgroup_unified['configured']}" in
                yes)
                    print_ok "cgroup2 unified hierarchy is mounted to /sys/fs/cgroup and configured in /etc/default/grub."
                    ;;
                needupdate)
                    print_fail "cgroup2 unified hierarchy is mounted to /sys/fs/cgroup and configured in /etc/default/grub, but not updated." "Please run 'grub2-mkconfig -o /boot/grub2/grub.cfg' to update"
                    ((fails++))
                    ;;
                no)
                    print_fail "cgroup2 unified hierarchy is mounted to /sys/fs/cgroup, but not configured in /etc/default/grub." "Please rewrite the bootloader and reboot."
                    ((fails++))
                    ;;
            esac  
            ;;
        no)
            case "${cgroup_unified['configured']}" in 
                yes)
                    print_fail "cgroup2 unified hierarchy is configured in /etc/default/grub, but not active!" "Please rewrite the bootloader and reboot."    
                    ;;
                needupdate)
                    print_fail "cgroup2 unified hierarchy is configured in /etc/default/grub, but not updated and active!" "Please rewrite the bootloader, run 'grub2-mkconfig -o /boot/grub2/grub.cfg' and reboot."
                    ;;
                no)
                    print_fail "cgroup2 unified hierarchy is not configured!" "Please add 'systemd.unified_cgroup_hierarchy=true' to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, rewrite the bootloader and reboot."    
                    ;;
            esac
            ((fails++))
            ;;
    esac


    # No cgroup v1 controller should be active.
    case "${cgroup_unified['v1-controllers']}" in 
        no)
            print_ok "No cgroup1 controllers mounted."
            ;;
        *memory*)
            print_fail "The cgroup1 memory controller has been found, which is not supported with WMP!" "Please configure your system according to the documentation." 
            ((fails++))
            ;;    
        *) 
            print_warn "The following cgroup1 controllers have been found: ${cgroup_unified['v1-controllers']}. Verify that they do not interfere with WMP."
            ;;
    esac

    # The capture program has to be have the permissions of 6750 and the ownership of root:sapsys
    case "${capture_state['exists']}" in 
        yes)
            case "${capture_state['permissions']}:${capture_state['ownership']}" in 
                6750:root:sapsys)
                    print_ok "capture program has correct ownership and permissions."
                    ;;
                *)
                    case "${capture_state['permissions']}" in 
                        4750)   
                            ;;
                        *)
                            print_fail "capture program has wrong permissions of ${capture_state['permissions']}!" "Reinstall the sapwmp package or change the permissions of ${capture_state['name']} to 6750."
                            ((fails++))
                            ;;
                    esac
                    case "${capture_state['ownership']}" in
                        root:sapsys)
                            ;;
                        *)
                            print_fail "capture program has wrong ownership of ${capture_state['ownership']}!" "Reinstall the sapwmp package or change the ownership of ${capture_state['name']} to root:sapsys. The SAP software has to be installed first!"
                            ((fails++))
                            ;;
                    esac
                    ;;
            esac
            ;;
        no)
            print_fail "capture program is missing!" "Reinstall the sapwmp package."
            ((fails++))
            ;;
    esac    

    # The instance profiles must call the capture program.
    if [ ${#SAP_profile_path[@]} -eq 0 ] ; then
        print_fail "Could not find any SAP instances!" "Check if SAP software has been installed correctly."
        ((fails++))
    else
        counter=0
        for instance in ${!SAP_profile_path[@]} ; do 
            case "${SAP_profile_wmp_entry[${instance}]}" in 
                -)
                    print_note "No entry for the WMP capture program found in ${SAP_profile_path[${instance}]}."
                    ;;
                *)
                    print_note "WMP entry for the WMP capture program found for instance ${instance}."
                    ((counter++))
                    ;;
            esac 
        done
        case "${counter}" in 
            0)
                print_fail "All SAP instances miss the entry for the WMP capture program!" "Add the entry to the instance profile of the chosen instances."
                ((fails++))
                ;;
            ${#SAP_profile_path[@]})
                print_ok "All SAP instances contain the entry for the WMP capture program."
                ;;
            *)
                print_warn "Only part of the SAP instances have been configured for WMP."
                ((warnings++))
                ;;
        esac
    fi

    # The SAP slice must exists and be configured sanely.
    case "${SAP_slice_data['exists']}" in
        yes)
            case "${SAP_slice_data['state_active']}" in  
                active)
                    print_ok "SAP slice is active."
                    case "${SAP_slice_data['MemoryLow']}" in 
                        0|18446744073709551615)
                            print_fail "MemoryLow of ${SAP_slice_data['name']} is not set correctly to ${SAP_slice_data['MemoryLow']}!" "Please set MemoryLow to a correct value."
                            ((fails++))
                            ;;    
                        *)
                            page_size=$(getconf PAGE_SIZE)
                            if [ $(( ${SAP_slice_data['MemoryLow']:-0} / ${page_size} )) -eq $(( ${SAP_slice_data['memory.low']:-0} / ${page_size} )) ] ; then
                                print_ok "MemoryLow is set and in use."
                            else
                                print_fail "The cgroup ${SAP_slice_data['name']} has a different value for memory.low (${SAP_slice_data['memory.low']}) as configured for MemoryLow (${SAP_slice_data['MemoryLow']})" "Only the configuration file or the runtime value has been changed!"
                                ((fails++))
                            fi
                            ;;
                    esac
                    ;;
                inactive)
                    print_fail "${SAP_slice_data['name']} is not active!" "Check if the SAP instances are started."
                    ((fails++))
                    ;;
            esac
            case "${SAP_slice_data['memory_low_children']}" in
                false)
                    eval $(grep ^VERSION= /etc/os-release)

                    case "${VERSION}" in
                        15-SP4)
                            print_ok "In SLE15SP4, subcgroups of ${SAP_slice_data['name']} without MemoryLow setting is acceptable."
                            ;;
                        *)
                            print_fail "Subcgroups (${SAP_slice_data['unprotect_list']}) of ${SAP_slice_data['name']} have either no MemoryLow setting or are not set to maximum!" "Refer to the SUSE doc and check what has changed the parameters then restart the SAP instances."
                            ((fails++))
                            ;;
                    esac

            esac
            ;;
        no)
            print_fail "Unit file for ${SAP_slice_data['name']} is missing!" "Reinstall the sapwmp package."
            ((fails++))
            ;;
    esac

    # All instance processes must be in SAP.slice.
    if [ ${SAP_processes} -eq 0 ] ; then
        print_fail "No SAP instance processes found!" "Please start the SAP system."
        ((fails++))
    else
        for instance in "${!SAP_instance_processes[@]}" ; do
            case "${SAP_processes_outside_cgroup[${instance}]}" in
                '')
                    print_ok "All processes of ${instance} are in SAP.slice."
                    ;;
                *)
                    print_fail "Instance ${instance} has processes outside SAP.slice:${SAP_processes_outside_cgroup[${instance}]}."
                    ((fails++))
                    ;;
            esac
        done
     fi


    # Check if MemoryLow of the SAP slice is lower the memory.current and less then 3% as physical memory.
    if [ -n "${SAP_slice_data['MemoryLow']}" ] ; then
        if [ ${SAP_slice_data['MemoryLow']} -gt ${SAP_slice_data['memory.current']} ] ; then 
            print_ok "MemoryLow is larger then the current allocated memory for ${SAP_slice_data['name']}."
        else
            print_fail "MemoryLow (${SAP_slice_data['MemoryLow']}) is smaller then the current allocated memory (${SAP_slice_data['memory.current']}) for ${SAP_slice_data['name']}!" "Check if this is an expected situation."
            ((fails++))
        fi
        if [ ${SAP_slice_data['MemoryLow']} -lt ${memory_info['MemTotal']} ] ; then
            print_ok "MemoryLow of ${SAP_slice_data['name']} is less then total memory."
            memory_low_thresh=$(( ${memory_info['MemTotal']} * 97 / 100 ))
            if [ ${SAP_slice_data['MemoryLow']} -gt ${memory_low_thresh} ] ; then
                print_warn "MemoryLow of ${SAP_slice_data['name']} (${SAP_slice_data['MemoryLow']}) is very close to the total physical memory (${memory_info['MemTotal']})!"
                ((warnings++))
            fi
        else
            print_fail "MemoryLow of ${SAP_slice_data['name']} (${SAP_slice_data['MemoryLow']}) is not less then the total physical memory (${memory_info['MemTotal']})!" "Reduce MemoryLow."
            ((fails++))
        fi
    else
        print_fail "MemoryLow of ${SAP_slice_data['name']} is not configured!" "Configure MemoryLow."
        ((fails++))
    fi

    # Check if the optional monitoring has been enabled.
    case "${unit_state_active['wmp-sample-memory.timer']}" in 
        active)
                print_note "The timer unit wmp-sample-memory.timer to collect monitor data is active."
                ;;
        inactive)
                print_note "The timer unit wmp-sample-memory.timer to collect monitor data is not active."
                ;;
    esac
    case "${unit_state_enabled['wmp-sample-memory.timer']}" in 
        enabled)
                print_note "The optional timer unit wmp-sample-memory.timer to collect monitor data is enabled."
                ;;
        disabled)
                print_note "The optional timer unit wmp-sample-memory.timer to collect monitor data is disabled."
                ;;
    esac

    # Check if optional swap accounting is configured and enabled.
    case "${swapaccounting_state['active']}" in
        yes)
            print_note "Optional swap accounting is active and can be monitored."
            ;;
        no)
            print_note "Optional swap accounting is not active at the moment."
            ;;
    esac  
    case "${swapaccounting_state['configured']}" in 
        yes)
            print_note "Optional swap accounting is configured in /etc/default/grub."    
            ;;
        no)
            print_note "Optional swap accounting is not configured in /etc/default/grub."
            ;;
    esac

    # Summary.
    echo
    [ ${warnings} -gt 0 ] && echo -e "${YELLOW}${warnings} warning(s)${RESET} have been found."
    [ ${fails} -gt 0 ] && echo -e "${RED}${fails} error(s)${RESET} have been found."
    if [ ${fails} -gt 0 ] ; then
        echo "WMP will not work properly!"
        return 1
    else 
        if [ ${warnings} -gt 0 ] ; then
            echo "WMP should work properly, but better investigate!"
        else
            echo "WMP is set up correctly."
        fi
    fi
    return 0    
}


# --- MAIN ---

# Introduction.
echo -e "\nThis is ${0##*/} v${version}."
echo -e "It verifies if WMP is set up correctly.\n"
echo -e "Please keep in mind:"
echo -e " - It does not check if you have the latest version installed, only minimum version."
echo -e " - It assumes SAP instances profiles can be found beneath /usr/sap/<SID>/SYS/profile/."
echo -e " - This tool does not check, if the memory.low value is set correctly.\n"

# Determine if we are running a SLES for SAP Applications 15.  #####  CHANGED TO RUN ON LEAP !! #######
eval $(grep ^ID= /etc/os-release)
eval $(grep ^VERSION= /etc/os-release)
PROD=""

[ -f "/etc/products.d/SLES_SAP.prod" ] && PROD="4sap"
case "${ID}${PROD}-${VERSION-ID}" in
    sles4sap-15|sles4sap-15-SP1|sles4sap-15-SP2|sles4sap-15-SP3|sles4sap-15-SP4)
        ;;
    *)
        echo "Only SLES for SAP Applications 15 SP0/1/2/3/4 are supported! Your OS is ${ID}${PROD}-${VERSION}. Exiting."
        exit 2
        ;;
esac

# Check parameters and act upon.
case "${#}" in
    0)  collect_data
        check_wmp
        exit $?
        ;;
    *)  echo "Usage: ${0##*/}"
        exit 3
        ;;
esac

# Bye.
exit 0

