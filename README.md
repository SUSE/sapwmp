# WMP configuration

This repo and scripts serve to provide reference configuration files, their
version tracking and reproducible deployment as RPM package.

## How to use this

  * Install/remove RPM `sapwmp-profile`.
  * Update SAP profiles (TODO add more info)

## Making updates

  * Commit into git, the trigger service in [IBS project](https://build.suse.de/package/show/home:mkoutny:wmp/sapwmp-profile)
    to rebuild RPM.

## TODO

  * RPM: fillup removal?
  * RPM: daemon-reload post install
  * RPM: ensure existence of sapsys group before installation

  * doc
