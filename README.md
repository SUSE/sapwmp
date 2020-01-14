# WMP configuration

This repo and scripts serves to provide reference configuration files, their
version tracking and reproducible deployment as RPM package.

## How to use this

  * Clone the repository on the target machine.
    * If git isn't available, checkout desired branch locally and copy files
      manually.
  * Run `install.sh` (as root) to carry out the configuration.
  * To revert configuration call `uninstall.sh`.
    * **Always use install and unistall script with same versions!**
      * E.g. checkout two working copies to be sure.

## Making updates

  * **Never forget to bump VERSION in `install.sh` script.**
    * It can be any string but make sure that different versions have always
      different string.
  * Strive to keep configuration as a set of config files.
    * Put them under `files/` directory that represents root of the target
      system.
  * Advanced changes should be put into "post (un)install" sections in
    `install.sh` script.
    * Update both install and uninstall (reverse).
    * Install and uninstall should be idempotent operations.
    * Install+uninstall should be net zero.
  * Use different branches for different approaches.

## Gotchas

  * The operations aren't atomic, so be careful when changing the install
    script.
