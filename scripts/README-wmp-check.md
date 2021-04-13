# [wmp-check.sh](./wmp-check.sh)
> This script originally developed in repo https://github.com/scmschmidt/wmp_check.git
> Merged into this repo at v1.1.1

This script checks the setup of Workload Memory Protection.

- Correct setup of cgroup2
- Checc the required rpm packages version
- Ownership and permission of the capture program
- WMP entries of SAP instance profiles
- Correct cgroup of running SAP instance processes.
- Correct setup of SAP.slice
- Sane configuration of MemoryLow (It can not determine, if the MemoryLow value has been chosen wisely!)
- Setup of the optional memory sampler
- Setup of optional swap accounting

Please keep in mind:

 - It does not check if you have the latest version installed, only minimum version.
 - It assumes SAP instances profiles can be found beneath /usr/sap/<SID>/SYS/profile/.
 - This tool does not check, if the memory.low value is set correctly.


## Usage
```
wmp-check.sh
```

## Examples

WMP has been setup correctly for all three existent SAP instances:

```
# ./wmp-check.sh

This is wmp_check v0.1.
It verifies if WMP is set up correctly.

Please keep in mind:
 - It does not check if you have the latest version installed.
 - It assumes SAP instances profiles can be found beneath /usr/sap/<SID>/SYS/profile/.
 - This tool does not check, if the memory.low value is set correctly.

[ OK ]  cgroup2 unified hierarchy is mounted to /sys/fs/cgroup and configured in /etc/default/grub.
[ OK ]  capture program has correct ownership and permissions.
[NOTE]  WMP entry for the WMP capture program found for instance HA0_ASCS00_sapha0as.
[NOTE]  WMP entry for the WMP capture program found for instance HA0_D01_sapha0ci.
[NOTE]  WMP entry for the WMP capture program found for instance HA0_ERS10_sapha0er.
[ OK ]  All SAP instances contain the entry for the WMP capture program.
[ OK ]  SAP slice is active.
[ OK ]  MemoryLow is set and in use.
[NOTE]  All processes of HA0_ASCS00_sapha0as are in SAP.slice.
[NOTE]  All processes of HA0_D01_sapha0ci are in SAP.slice.
[NOTE]  All processes of HA0_ERS10_sapha0er are in SAP.slice.
[ OK ]  All SAP instance processes are inside SAP.slice.
[ OK ]  MemoryLow is not larger then the current allocated memory for SAP.slice.
[ OK ]  MemoryLow of SAP.slice is less then total memory.
[NOTE]  The timer unit wmp-sample-memory.timer to collect monitor data is active.
[NOTE]  The optional timer unit wmp-sample-memory.timer to collect monitor data is enabled.
[NOTE]  Optional swap accounting is active and can be monitored.
[NOTE]  Optional swap accounting is configured in /etc/default/grub.

WMP is set up correctly.
```

Changing the instance profiles have been forgotten and the SAP instances are not running:

```
# ./wmp-check.sh

This is wmp_check v0.1.
It verifies if WMP is set up correctly.

Please keep in mind:
 - It does not check if you have the latest version installed.
 - It assumes SAP instances profiles can be found beneath /usr/sap/<SID>/SYS/profile/.
 - This tool does not check, if the memory.low value is set correctly.

[ OK ]  cgroup2 unified hierarchy is mounted to /sys/fs/cgroup and configured in /etc/default/grub.
[ OK ]  capture program has correct ownership and permissions.
[NOTE]  No entry for the WMP capture program found in /usr/sap/HA0/SYS/profile/HA0_ASCS00_sapha0as.
[NOTE]  No entry for the WMP capture program found in /usr/sap/HA0/SYS/profile/HA0_D01_sapha0ci.
[NOTE]  No entry for the WMP capture program found in /usr/sap/HA0/SYS/profile/HA0_ERS10_sapha0er.
[FAIL]  All SAP instances miss the entry for the WMP capture program!
        -> Add the entry to the instance profile of the chosen instances.
[ OK ]  SAP slice is active.
[ OK ]  MemoryLow is set and in use.
[NOTE]  Instance HA0_ASCS00_sapha0as has processes outside SAP.slice: 24697 24753 24751 24079.
[NOTE]  Instance HA0_D01_sapha0ci has processes outside SAP.slice: 24730 25159 25211 25212 25214 25215 25216 25217 25218 25219 25229 25228 25221 25220 25223 25222 25225 25224 25227 25226 25234 25232 25233 25230 25231.
[NOTE]  Instance HA0_ERS10_sapha0er has processes outside SAP.slice: 24306 24935 24947.
[FAIL]  All SAP instances are outside SAP.slice!
        -> Check your configuration and restart the instance.
[ OK ]  MemoryLow is not larger then the current allocated memory for SAP.slice.
[ OK ]  MemoryLow of SAP.slice is less then total memory.

2 error(s) have been found.
WMP will not work properly!
```

WMP has been setup correctly for all three existent SAP instances, but there is a warning about 
MemoryLow which *might* be to high and leaves to less memory for the rest of the system:

```
# ./wmp-check.sh

This is wmp_check v0.1.
It verifies if WMP is set up correctly.

Please keep in mind:
 - It does not check if you have the latest version installed.
 - It assumes SAP instances profiles can be found beneath /usr/sap/<SID>/SYS/profile/.
 - This tool does not check, if the memory.low value is set correctly.

[ OK ]  cgroup2 unified hierarchy is mounted to /sys/fs/cgroup and configured in /etc/default/grub.
[ OK ]  capture program has correct ownership and permissions.
[NOTE]  WMP entry for the WMP capture program found for instance HA0_ASCS00_sapha0as.
[NOTE]  WMP entry for the WMP capture program found for instance HA0_D01_sapha0ci.
[NOTE]  WMP entry for the WMP capture program found for instance HA0_ERS10_sapha0er.
[ OK ]  All SAP instances contain the entry for the WMP capture program.
[ OK ]  SAP slice is active.
[ OK ]  MemoryLow is set and in use.
[NOTE]  All processes of HA0_ASCS00_sapha0as are in SAP.slice.
[NOTE]  All processes of HA0_D01_sapha0ci are in SAP.slice.
[NOTE]  All processes of HA0_ERS10_sapha0er are in SAP.slice.
[ OK ]  All SAP instance processes are inside SAP.slice.
[ OK ]  MemoryLow is not larger then the current allocated memory for SAP.slice.
[WARN]  MemoryLow of SAP.slice (15498389487) is very close to the total physical memory (15977289039)!
[NOTE]  The timer unit wmp-sample-memory.timer to collect monitor data is active.
[NOTE]  The optional timer unit wmp-sample-memory.timer to collect monitor data is enabled.
[NOTE]  Optional swap accounting is active and can be monitored.
[NOTE]  Optional swap accounting is configured in /etc/default/grub.

WMP is set up correctly.
```


## Exit Codes
| exit code | description                                                        |
|-----------|--------------------------------------------------------------------|
|     0     | All checks ok. WMP has been set up correctly.                      |
|     1     | Some warnings occured. WMP should work, but better check manually. |
|     2     | Some errors occured. WMP will not work.                            |
|     3     | Wrong parameters given to the tool on commandline.                 |


## Changelog

|    date    | version  | comment                                               |
|------------|----------|-------------------------------------------------------|
| 12.10.2020 | v1.0     | First release                                         |
| 13.10.2020 | v1.0.1   | Added check of memory.low=max for SAP.slice children  |
| 03.11.2020 | v1.0.2   | Fixed wrong permissions in capture program test       |
|            |          | Fixed OS version detection                            |
|            |          | Fixed issues with MemoryLow test                      |
|            |          | Fixed issues with profile detection                   |
|            |          | Fixed issue with cgroup detection                     |
|            |          | Added cgroup v1 detection                             |
| 09.12.2020 | v1.0.3   | Optimized pattern for profile detection               |
| 14.12.2020 | v1.1.0   | cgroup2 mount detection fixed                         |
|            |          | Further optimized pattern for profile detection       |
|            |          | Detection of SAP instances reworked a bit             |
| 09.04.2021 | v1.1.1   | Add colorful output                                   |
|            |          | Check generated grub2 configure                       |
|            |          | Enable support for SLE15SP0/SP1                       |
|            |          | Support RPM package version check                     |
