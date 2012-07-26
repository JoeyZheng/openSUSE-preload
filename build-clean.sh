#!/bin/bash
#
# cleanup physical extension

test -n "$PHYS_DIR" || PHYS_DIR=/data/kiwi-root
test -n "$TMPFS_DIR" || TMPFS_DIR=$PHYS_DIR/shm

echo "Cleanup physical extension $PHYS_DIR/root..."
umount $TMPFS_DIR >/dev/null 2>&1
rm -rf $TMPFS_DIR
rm -rf $PHYS_DIR/phys
rm -f $PHYS_DIR/phys.*.sc*
rm -f $PHYS_DIR/phys.log_run*

exit 0
