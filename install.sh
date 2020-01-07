#!/bin/bash

# Make sure to update this when changing setup
VERSION=2
VERSION_FILE=/etc/wmp-version

BAK_SUFFIX=.wmpbak

case $(basename "$0") in
	install.sh)
		verb=run_install
		;;
	uninstall.sh)
		verb=run_uninstall
		;;
	*)
		echo "Unknow invokation $0"
		exit 1
		;;
esac

pushd `dirname $0` &>/dev/null
ROOT="$PWD/files"
popd &>/dev/null


function install_file() {
	SRC="$ROOT/$1"
	DST="/$1"
	BAK=$DST$BAK_SUFFIX

	if [ -f "$DST" ] ; then
		echo "$DST already exists, making backup $BAK"
		cp "$DST" "$BAK"
	elif [ ! -d $(dirname "$DST") ] ; then
		mkdir -p $(dirname "$DST")
	fi
	cp "$SRC" "$DST"
}

function uninstall_file() {
	DST="/$1"
	BAK=$DST$BAK_SUFFIX

	if [ ! -f "$DST" ] ; then
		echo "$DST not found, skipping"
		return
	elif [ -f "$BAK" ] ; then
		echo "$DST has backup, restoring $BAK"
		cp "$BAK" "$DST" && rm "$BAK"
	else
		echo "$DST removed"
		rm "$DST"
	fi
}

function run_install() {
	if [ -f "$VERSION_FILE" ] ; then
		local present_version=$(cat "$VERSION_FILE")
		if [ "$present_version" != "$VERSION" ] ; then
			echo "Version '$present_version' installed, uninstall that version first."
			exit 1
		else
			echo "Version '$present_version' already installed."
			exit 0
		fi
	fi

	echo "$VERSION" >"$VERSION_FILE"

	for f in `find $ROOT -type f` ; do
		name=${f#$ROOT/}
	
		install_file "$name"
	done

	# post install
	grep -q "systemd.unified_cgroup_hierarchy=true" /proc/cmdline || echo
		"Add systemd.unified_cgroup_hierarchy=true to kernel cmdline"
	# ---
}

function run_uninstall() {
	if [ ! -f "$VERSION_FILE" ] ; then
		echo "Nothing installed, nothing to do"
		exit 0
	else
		local present_version=$(cat "$VERSION_FILE")
		if [ "$present_version" != "$VERSION" ] ; then
			echo "Version '$present_version' installed, cannot uninstall that."
			exit 1
		fi
	fi

	for f in `find $ROOT -type f` ; do
		name=${f#$ROOT/}
	
		uninstall_file "$name"
	done

	# post uninstall
	grep -q "systemd.unified_cgroup_hierarchy=true" /proc/cmdline && echo
		"Remove systemd.unified_cgroup_hierarchy=true from kernel cmdline"
	# ---

	rm "$VERSION_FILE"
}

$verb
