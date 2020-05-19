# WMP

This repo and scripts serve to provide reference configuration files, their
version tracking and reproducible deployment as RPM package.

This is based on modifying SAP profile. For the rejected and unmaintained
variant see the branch

  * [PAM based](https://gitlab.suse.de/mkoutny/wmp-repo/tree/pam-rpm).

## How to use this

  * Install/remove RPM `sapwmp`.
  * Update respective SAP profiles by inserting call to the cgroup capture
    program into the start sequence:

```
...
Execute_20 = local /usr/lib/sapwmp/sapwmp-capture -a
# all programs spawned below will be put in dedicated cgroup
...
```

## Making updates

  * Commit into git, then trigger service in appropriate package of [IBS project](https://build.suse.de/package/show/home:mkoutny:wmp/)
    to rebuild RPM.
  * The submitted package has disabled services and a snapshot is commited into IBS.

## TODO

  * RPM: extensible (group) permissions 

