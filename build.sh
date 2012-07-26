#!/bin/bash

# set variables
set -a
test -z "$PHYS_DIR" && PHYS_DIR=/data/kiwi-root
test -z "$IMAGE_DIR" && IMAGE_DIR=/data/image
test -z "$LOG_DIR" && LOG_DIR=/data/log
TMPFS_DIR=$PHYS_DIR/shm
MAINTENANCE_TARBALL=maintenance-updates-20120723.tar.bz2
MAINTENANCE_DIR="${MAINTENANCE_TARBALL%.tar.bz2}"

# additional options set by the caller
# PHYS_SHM=yes      Use tmpfs for creating physical extension; needs lots of RAM
# PHYS_SHM_KEEP=yes Keep tmpfs phys. ext. for image creation; needs more RAM!

# in kb, 600 MB - should be enough
MIN_TMP_FREE=614400

# supported kiwi versions
SUPPORTED_KIWI_VERSIONS="kiwi-4.98.35"
set +a

# check that we're root.
if [ $EUID -ne 0 ]; then
	echo "Please run this script as root."
	exit 1
fi

# check architecture: only 32bit is supported
case $(uname -m) in
    i?86)
	;;
    *)
	echo "Invalid architecture.  Use linux32 or give up."
	exit 1
	;;
esac

# check installed OS
# openSUSE 12.1 is required
eval `sed -e 's/ *= */=/; /^VERSION\|CODENAME/p;d' < /etc/SuSE-release`
if [ "x$VERSION" = x12.1 -a "x$CODENAME" = xAsparagus ] ; then
	echo "Found supported build environment"
else
	echo "Unsupported build environment. Please update to openSUSE 12.1."
	exit 1
fi

# check that we have enough space left on /tmp - kiwi requires a certain amount
# /dev/sda6             10325748   8617740   1183488      88% /
tmp_used=`/bin/df -k /tmp|grep '^/'|sed -e 's_.* \([0-9]\+\)[ ]\+[0-9]\+%.*_\1_'`
test $tmp_used -lt $MIN_TMP_FREE && {
	echo "
	There is less than $MIN_TMP_FREE KB free in /tmp.
	This may cause problems with the Kiwi build process.
	Please free some space! Aborting."
	exit 1;
}

# check if a supported kiwi version is installed
for i in $SUPPORTED_KIWI_VERSIONS ; do
	if rpm -q $i > /dev/null ; then
		KIWI_VERSION="$i"
	fi
done
if [ -z $KIWI_VERSION ] ; then
	echo "KIWI not found or not supported. Please install one of the following versions: $SUPPORTED_KIWI_VERSIONS"
	while true; do
	read -p "Continue anyway? [y/n] " yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit;;
		esac
	done
else
	echo "Using $KIWI_VERSION"
fi

# get configuration
if [ "x$1" != x ] ; then
    IMAGE_TYPE="$1";
else
    for f in config-*.xml ; do
	# get first configuration that is actually an image config
	if head $f | grep "<image" >/dev/null 2>&1 ; then
	    f="${f%.xml}"
	    IMAGE_TYPE="${f#config-}"
	    break
	fi
    done
fi

if [ -z $IMAGE_TYPE ] ; then
	echo "IMAGE_TYPE not set. Using config.xml as a fallback";
else
	echo "Using configuration $IMAGE_TYPE..."
	if cp -f "config-$IMAGE_TYPE.xml" config.xml ; then :; else
		echo 1>&2 "Cannot find config-$IMAGE_TYPE.xml"
		exit 1
	fi
fi

# get version
VERSION=`sed -n 's/.*<version>[[:space:]]*\([0-9.]*\)[[:space:]]*<\/version>.*/\1/p' config.xml`
if [ -n "$EXTRA_VERSION" ]; then
    case $VERSION in
	*.*.*)
	    VERSION=${VERSION%.*}
	    ;;
    esac
    VERSION=$VERSION.$EXTRA_VERSION
    # replace with the given version
    sed -i -e's/^\(.*<version>[[:space:]]*\)[0-9.]*\([[:space:]]*<\/version>.*\)$/\1'$VERSION'\2/' config.xml
fi
LOG_VERSION=$VERSION.$(date +%Y%m%d_%H%M)

# check whether the target image already exists
image_base_name=$(grep '^<image' config.xml | sed -e's/^.*name="\([^ "]*\)".*$/\1/')
image_base_name=$image_base_name.i686
if [ -f "$IMAGE_DIR/$image_base_name-$VERSION.iso" ]; then
    echo "Image ISO file $IMAGE_DIR/$image_base_name-$VERSION.iso already exists."
    echo "Remove the file first if you want to build the same image again."
    exit 1
fi

# unpack maintenance update tarball
if [ ! -f $MAINTENANCE_TARBALL ]; then
    echo "No maintenance update tarball found!"
    exit
fi
if [ ! -d $MAINTENANCE_DIR ]; then
	echo "Unpacking maintenance update tarball"
	tar xvf $MAINTENANCE_TARBALL >/dev/null
else
	echo "Found unpacked maintenance tarball"
fi

# cleanup physical extension
echo "Cleanup physical extension $PHYS_DIR..."
umount $TMPFS_DIR >/dev/null 2>&1
rm -rf $TMPFS_DIR
rm -rf $PHYS_DIR/phys
rm -f $PHYS_DIR/phys.*.sc*
rm -f $PHYS_DIR/phys.log_run*

# create and mount root dir
PHYS_ROOT=$PHYS_DIR
mkdir -p $PHYS_DIR
if [ "$PHYS_SHM" = "yes" ]; then
    PHYS_ROOT=$TMPFS_DIR
    mkdir -p $TMPFS_DIR
    mount -t tmpfs -onoatime,size=10g phys $TMPFS_DIR
fi

# check whether pigz is available
if [ -x /usr/bin/pigz ]; then
    gzip_cmd="--gzip-cmd=pigz"
else
    gzip_cmd=""
fi

echo "*** BUILD CONDITION ***"
echo "Physical extension = $PHYS_ROOT/phys"
if [ "$PHYS_SHM" = "yes" ]; then
    echo "Use tmpfs ($TMPFS_DIR) to physical extension"
    if [ "$PHYS_SHM_KEEP" = "yes" ]; then
	echo "Keep tmpfs phys. ext. for image creation"
    fi
fi
if [ -n "$gzip_cmd" ]; then
    echo "GZIP command: $gzip_cmd"
fi

# create physical extension
echo "Creating physical extension..."
if ( ! kiwi -p . -r $PHYS_ROOT/phys $gzip_cmd ) ; then
    echo "    Image preparation failed!\n"
    exit;
fi

# save log from creation of the physical extension
echo "Saving log to phys.log_run_1 ..."
mv $PHYS_ROOT/phys.log $PHYS_DIR/phys.log_run_1

# validate 'repo' rpms
echo "Validating rpms from repo/ ..."
for f in repo/*.rpm ; do
    p=`rpm -qp "$f" --qf "%{NAME}"`
    e=`rpm -qp "$f" 2>/dev/null`
    i=`rpm -q --root "$PHYS_ROOT/phys" "$p" 2>/dev/null`
    if [ "x$i" != "x$e" ] ; then
	echo "NOTE: rpm version mismatch; expected $e, installed $i"
	echo "NOTE: rpm version mismatch; expected $e, installed $i" >> $PHYS_DIR/phys.log_run_1
    fi
done
if [ -d "$LOG_DIR" ]; then
    logbackup=$LOG_DIR/log_run_1.$LOG_VERSION
    cp $PHYS_DIR/phys.log_run_1 $logbackup
    gzip $logbackup
    # save package list
    rpm -qa --root "$PHYS_ROOT/phys" | sort > $LOG_DIR/rpmlist.$LOG_VERSION
fi

if [ "$PHYS_SHM" = "yes" -a "$PHYS_SHM_KEEP" != "yes" ]; then
    # copy phys. ext. from tmpfs to local disk for the further process
    date
    echo "Copying tmpfs image to $PHYS_DIR/phys"
    rm -rf $PHYS_DIR/phys
    cp -a $PHYS_ROOT/phys $PHYS_DIR
    PHYS_ROOT=$PHYS_DIR
    # clear tmpfs
    fuser -m $TMPFS_DIR -k
    umount $TMPFS_DIR
    rm -rf $TMPFS_DIR
fi

# create kiwi image
echo "Creating image"
mkdir -p $IMAGE_DIR
if ( ! kiwi -c $PHYS_ROOT/phys -d $IMAGE_DIR/ $gzip_cmd ); then
    echo "    Image creation failed!\n"
    exit;
fi

# save log from creation of image
echo "Saving log to phys.log_run_2 ..."
mv $PHYS_ROOT/phys.log $PHYS_DIR/phys.log_run_2
if [ -d "$LOG_DIR" ]; then
    logbackup=$LOG_DIR/log_run_2.$LOG_VERSION
    cp $PHYS_DIR/phys.log_run_2 $logbackup
    gzip $logbackup
fi

if [ -n "$BUILDROOT" ]; then
    cd ..
    rm -rf $BUILDROOT
fi 

exit 0
