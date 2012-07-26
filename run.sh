#!/bin/sh
#
# Build an openSUSE preload image in a chroot environment
#

# create symlinks to maintenance-updates (tarball)
MAINTENANCE_TARBALL=maintenance-updates-20120723.tar.bz2
MAINTENANCE_DIR="${MAINTENANCE_TARBALL%.tar.bz2}"

if [ ! -e $MAINTENANCE_TARBALL ] ; then
        ln -s /data/maintenance-updates/$MAINTENANCE_TARBALL $MAINTENANCE_TARBALL
fi
if [ ! -d $MAINTENANCE_DIR ] ; then
        ln -s /data/maintenance-updates/$MAINTENANCE_DIR/ $MAINTENANCE_DIR
fi

# check memory size and determine the build condition
mem=$(grep '^MemTotal:' /proc/meminfo | sed -e's/MemTotal: *\(.*\) kB/\1/')
echo "Memory = $mem kB"

# export PHYS_DIR=/data/build-test

export PHYS_SHM=yes
unset PHHS_SHM_KEEP

time ./build.sh $@

