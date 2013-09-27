#!/bin/bash
# A simple tool to run a script inside a rootfs

ISO=$1
shift 1
EDITCMD=$1
shift 1
EDITCMDARGS=$@


#
# Some patch used later on
#
SESSIONDIR=$(mktemp -d --dry-run /var/tmp/edit-img.XXXXX)
ISOMP="$SESSIONDIR/iso-target"
NESTED_SQUASHFSIMG="$ISOMP/LiveOS/squashfs.img"
SQUASHFSMP="$SESSIONDIR/squashfs-target"
NESTED_ROOTFSIMG="$SQUASHFSMP/LiveOS/ext3fs.img"

ROOTFSIMG="$SESSIONDIR/ext3fs.img"
SQUASHFSIMG="$SESSIONDIR/squashfs.img"
NEW_ISO_ROOT="$SESSIONDIR/new-iso-root"

CLEANCMDS=()


#
# We are using colors to highlight/differentiate the output of guestfs
#
ESC_SEQ="\x1b["
col_reset() { echo -e $ESC_SEQ"39;49;00m"; }
col_red() { echo -e $ESC_SEQ"31;01m"; }
col_green() { echo -e $ESC_SEQ"32;01m"; }
col_yellow() { echo -e $ESC_SEQ"33;01m"; }
col_blue() { echo -e $ESC_SEQ"34;01m"; }
col_magenta() { echo -e $ESC_SEQ"35;01m"; }
col_cyan() { echo -e $ESC_SEQ"36;01m"; }


#
# Commands
#

log() { echo "($(date)) $@" ; }
debug() { [[ -z ${DEBUG} ]] ||  log "[DEBUG] $@" ; }

EDITCMDS="info yum-install sh"
usage() { echo -e "Usage: $0 <isoname> <cmd>\nAvailable Commands: $EDITCMDS" ; }

extract_rootfs() {
# FIXME This currently works by mounting the nested images into the hosts FS
# Maybe this can be done directly within guestfish
# guestmount might use FUSE, which ain't available on RHEL
	log "Extracting rootfs from '$ISO'"
	mkdir -p "$ISOMP"
	guestmount --ro -a "$ISO" -m /dev/sda1:/ "$ISOMP"
	mkdir -p "$SQUASHFSMP"
# Needs: setsebool -P virt_use_fusefs 1
	guestmount --ro -a "$NESTED_SQUASHFSIMG" -m /dev/sda:/ "$SQUASHFSMP"
	cp -v "$NESTED_ROOTFSIMG" "$ROOTFSIMG"
	CLEANCMDS+=("guestunmount '$SQUASHFSMP' ;")
	CLEANCMDS+=("guestunmount '$ISOMP' ;")
	CLEANCMDS+=("rmdir -v '$ISOMP' '$SQUASHFSMP' ;")
	CLEANCMDS+=("rm -v '$ROOTFSIMG' ;")
	CLEANCMDS+=("rmdir -v '$SESSIONDIR' ;")
}


_edit_rootfs() {
# Run the scriptfile given as the first argument within the rootfs
	GUESTFISH=guestfish
	[[ -z $DEBUG ]] || GUESTFISH="guestfish -x"
	LOCALFILE=$1
	log "Editing rootfs using '$LOCALFILE'"
	local REMOTEFILE="/tmp/edit-rootfs"
col_magenta
	$GUESTFISH --network <<EOG
add "$ROOTFSIMG"
run
mount /dev/sda /
upload "$LOCALFILE" "$REMOTEFILE"
sh "bash -x $REMOTEFILE"
rm "$REMOTEFILE"
exit
EOG
col_reset
}

_edit_rootfs_run_cmd() {
# Run the cmd given as the first argument within the rootfs
# This happens by creating a scriptfile from the cmd and running that using _edit_rootfs
	local INNERSCRIPT=$(mktemp -p "$SESSIONDIR" -t innerscript.XXXXX)
	debug "Will be running the command: $@"
	echo "$@" > $INNERSCRIPT
	_edit_rootfs "$INNERSCRIPT"
	CLEANCMDS+=("rm -v '$INNERSCRIPT' ;")
}

edit_rootfs_predefined_cmd() {
# Run a predefined command in the rootfs
	[[ $EDITCMD == "info" ]] && {
		log "Gathering image infos." ;
		_edit_rootfs_run_cmd "cat /etc/system-release ; rpm -qa | egrep '(ovirt)'" ;
	}
	[[ $EDITCMD == "yum-install" ]] && {
		log "Installing the package(s) '$EDITCMDARGS' inside the image."
		shift 1 ;
		_edit_rootfs_run_cmd "/usr/bin/yum install --enablerepo=* -d2 -v -y $EDITCMDARGS" ;
	}
	[[ $EDITCMD == "sh" ]] && { shift 1 ; _edit_rootfs "$EDITCMDARGS" ; }
}

repackage_rootfs() {
	log "Repackaging rootfs image '$ROOTFSIMG' into new squashfs '$SQUASHFSIMG'"

# FIXME reuse existing logic

#	mksquashfs "$ROOTFSIMG" "$SQUASHFSIMG" -comp lzo -root-becomes LiveOS -progress
#	unsquashfs -ll "$SQUASHFSIMG"

#	mkdir "$NEW_ISO_ROOT"
#	cp -v "$ISOMP"/* "$NEW_ISO_ROOT"
}

main() {
	extract_rootfs
	edit_rootfs_predefined_cmd
	repackage_rootfs
	eval ${CLEANCMDS[@]}
}



debug "Using ISO: $ISO"
debug "Using cmd: $EDITCMD $EDITCMDARGS"


if [[ -z $EDITCMD ]]
then
	usage
else
	main
	col_red
	log "NOTE: This is a POC! No ISO is created, some command swon't work as expected and the modified image is removed at the end."
	col_reset
fi

