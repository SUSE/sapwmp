# WMP configuration

This repo and scripts serve to provide reference configuration files, their
version tracking and reproducible deployment as RPM package.

## How to use this

  * Install/remove RPM `sapwmp-profile`.
  * Update respective SAP profiles by inserting call to the cgroup capture
    program into the start sequence:

```
...
Execute_20 = local /usr/sbin/sapwmp-capture -a
# all programs spawned below will be put in dedicated cgroup
...
```

## Making updates

  * Commit into git, the trigger service in [IBS project](https://build.suse.de/package/show/home:mkoutny:wmp/sapwmp-profile)
    to rebuild RPM.

## TODO

  * RPM: extensible (group) permissions 

