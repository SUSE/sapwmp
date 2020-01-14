# WMP configuration

This repo and scripts serves to provide reference configuration files, their
version tracking and reproducible deployment as RPM package.

## How to use this

  * Install/remove RPM `sapwmp`.

## Making updates

  * Commit into git, the trigger service in [IBS project](https://build.suse.de/package/show/home:mkoutny:wmp/sapwmp)
    to rebuild RPM.
  * Use different branches for different approaches.

## TODO

  * PAM: Black/white listing based on `comm`
  * PAM: Simplify sources of applicable users?
  * PAM: modifying common-session vs common-session-pc

  * cgroup: children with infinity or enable only on parent?
  * cgroup: make sure target cgroup exists (e.g. in HA)

  * RPM: fillup removal?
  * RPM: daemon-reload post install

  * doc
