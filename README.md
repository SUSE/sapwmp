# WMP

This repo contains sapwmp-capture utility and reference configuration files, so
that their version is tracked and can be deplyoed in uniform way as RPM
package.
(Ideally, SAP would be an ordinary systemd service and all this stuff would be
just a paragraph in our documentation how to add `MemoryLow=`.)

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

More details about SAP WMP in general is in
[SUSE doc](https://documentation.suse.com/sles-sap/15-SP2/html/SLES-SAP-guide/cha-memory-protection.html).
[Confluence](https://confluence.suse.com/display/SAP/Workload+Memory+Protection).


## Making updates

  * Commit everything into git (changelog is generated from it), then run `iosc
    service disabledrun` locally and commit into your IBS package.
  * When preparing a MU, submit from your package into the respective target.


## Tools

  * [wmp-check.sh](./scripts/wmp-check.sh)
```
# A script checks the setup of Workload Memory Protection.
$ wmp-check.sh
```
