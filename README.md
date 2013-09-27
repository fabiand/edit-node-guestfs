edit-node-guestfs
=================

> Note: This is a POC!

A guestfs based edit-node.

This is how it works:
1. guestfish is used to extract the ext3fs.img from an existing LiveCD ISO
2. guestfish is used to run a script inside the ext3fs.img (which is mounted inside a VM)
3. Classic tools are used to rebuild the LiveCD ISO (TBD)

Usage:

    edit-iso.sh <isoname> <cmd> [<cmdargs>]

Where
* `isoname` is the path to an existing ISO.
* `cmd` is a predefined cmd - a list of comands is printed when you don't provide a `<cmd>`
* `cmdargs` (optional) Some commands take arguments (like `yum-install`)

Example:

    edit-iso.sh <isoname> info

Will print some informations about the iso (system-release and ovirt rpms)
