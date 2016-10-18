#!/bin/bash
#
# vzprestore.sh
#
# A script meant to restore backups that have been taken with
# vzploopbackup. The script will create the relevant directories
# required to restore the container from a tar backup.
#
# Caution has been taken not to overwrite existing directories or
# config files. Please use caution as no detailed testing and error
# handling has been implemented as of yet.
#
# Author: Andreas Faerber, af@maeh.org

##
## DEFAULTS
##

ARCHIVE=
CONTAINER=
CONFIRM=yes
DELETE_BACKUP_SNAPSHOT=no

##
## VARIABLES
##

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
VZDIR=

## VARIABLES END

show_usage() {
    echo "Usage: $0 [--vzdir=<Directory to restore VE_PRIVATE and VE_ROOT to>] [--confirm=<yes/no>] [--delete-backup-snapshot=<yes/no>] <Filename> <CTID>"
    echo "Defaults:"
    show_param;
    echo
    echo "Note: Deleting the backup snapshot causes a switch to and a deletion"
    echo "      of the snapshot taken during backup. Doing so will cause any"
    echo "      running container to be rebooted. You will not be able to"
    echo "      resume the container from a suspended state."
    echo
    echo "You need to give at least <Filename> and <CTID> as arguments"
}

show_param() {
	echo "---";
	echo -e "Filename:\t\t\t$ARCHIVE"
	echo -e "Restore to container:\t\t$CONTAINER"
	if [ "x"$VE_PRIVATE == "x" ]; then
		echo -e "Restoring VZ to:\t\tGlobal Default"
	else
		echo -e "Restoring VE_PRIVATE:\t\t$VE_PRIVATE"
		echo -e "Restoring VE_ROOT:\t\t$VE_ROOT"
	fi
	echo -e "Confirm restore:\t\t$CONFIRM"
	echo -e "Delete Backup Snapshot:\t\t$DELETE_BACKUP_SNAPSHOT" 
	echo "---";
}

## Get global and local config, if there exists
if [ -f "/etc/vz/vzpbackup.conf" ]; then
	source "/etc/vz/vzpbackup.conf";
fi

if [ -f "./vzpbackup.conf" ]; then
	source "./vzpbackup.conf";
fi


for i in "$@"
do
case $i in
    --help)
    show_usage;
    exit 0;
    ;;
    --vzdir=*)
    	VZDIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --confirm=*)
    	CONFIRM=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --delete-backup-snapshot=*)
    DELETE_BACKUP_SNAPSHOT=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    *)
    	# Parse ARCHIVE and CTIDs here
	if [[ ! $i =~ ^\- ]]; then
		ARCHIVE=$CONTAINER
		CONTAINER=$i
	fi
    ;;
esac
done

ARC_EXT=${ARCHIVE##*.}

if [ "x"$ARCHIVE == "x" -o "x"$CONTAINER == "x" ]; then
    show_usage;
    exit 0;
fi
if [[ ! $CONTAINER =~ ^[0-9]+$ ]]; then
    show_usage;
    exit 0;
fi


ARCHIVE=`readlink -f $ARCHIVE`;

if [ ! -f $ARCHIVE ]; then
    echo "Archive $ARCHIVE does not exist or is inaccessible"
    exit 1;
fi

CTID=$CONTAINER
if [ "x"$VZDIR == "x" ]; then
    VE_PRIVATE=$(VEID=$CTID; source /etc/vz/vz.conf; echo $VE_PRIVATE)
    VE_ROOT=$(VEID=$CTID; source /etc/vz/vz.conf; echo $VE_ROOT)
else
    VE_PRIVATE=$VZDIR/private/$CTID
    VE_ROOT=$VZDIR/root/$CTID
fi
VE_DUMP=$(VEID=$CTID; source /etc/vz/vz.conf; echo $DUMPDIR)

show_param;
echo

if [ -d $VE_PRIVATE ]; then
    echo "Container private directory ($VE_PRIVATE) already exists, aborting"
    exit 0;
fi
if [ -d $VE_ROOT ]; then
    echo "Container root directory ($VE_ROOT) already exists, aborting"
    exit 0;
fi
if [ -d "/etc/vz/conf/$CTID.conf" ]; then
    echo "Container config file (/etc/vz/conf/$CTID.conf) already exists, aborting"
    exit 0;
fi

echo "Actions taken for restore:"
echo "mkdir $VE_ROOT"
echo "mkdir $VE_PRIVATE"
echo "cd $VE_PRIVATE"
echo "Extract backup archive into $VE_PRIVATE"
echo "Create container config /etc/vz/conf/$CTID.conf"
echo "Amend container config VE_ROOT: $VE_ROOT"
echo "Amend container config VE_PRIVATE: $VE_PRIVATE"
echo

if [ "x"$CONFIRM == "xyes" ]; then
    read -p "Confirm restore (yes/no): " INPUT
    if [ "x"$INPUT != "xyes" ]; then
        echo "Exiting.."
        exit 0;
    fi
fi

echo "Creating directory $VE_ROOT"
mkdir -p $VE_ROOT

echo "Creating direcotry $VE_PRIVATE"
mkdir -p $VE_PRIVATE

echo "cd into $VE_PRIVATE"
cd $VE_PRIVATE

echo "Extracting backup archive:"
if [ $ARC_EXT == "bz2" ]; then
	TAR_ARGS="-xvjf"
elif [ $ARC_EXT == "gz" ]; then
    TAR_ARGS="-zxvf"
elif [ $ARC_EXT == "xz" ]; then
	TAR_ARGS="-xJf"
else
    TAR_ARGS="-xvf"
fi
tar $TAR_ARGS $ARCHIVE

BACKUP_ID=$(cat $VE_PRIVATE/vzpbackup_snapshot)
echo BACKUP_ID: $BACKUP_ID
SRC_VE_CONF="dump/{$BACKUP_ID}.ve.conf"
echo "SRC VE CONF: $SRC_VE_CONF"
mv $SRC_VE_CONF /etc/vz/conf/$CTID.conf.new
egrep -v '^(VE_ROOT|VE_PRIVATE)' /etc/vz/conf/$CTID.conf.new > /etc/vz/conf/$CTID.conf
echo "VE_ROOT=$VE_ROOT" >> /etc/vz/conf/$CTID.conf
echo "VE_PRIVATE=$VE_PRIVATE" >> /etc/vz/conf/$CTID.conf
rm /etc/vz/conf/$CTID.conf.new

for f in $(ls -1 dump/{$BACKUP_ID}.ve.* 2>/dev/null)
do
    echo $f
    CONF_EXT=${f##*.}
    mv $f /etc/vz/conf/$CTID.$CONF_EXT.vzprestore
done

# Look for possible dump
DUMPFILE=${SRC_VE_CONF%.*.*}
echo DUMPFILE: $DUMPFILE
if [ -f $DUMPFILE ]; then
    echo "Found possible dump file.. moving it to $VE_DUMP"
    mv $DUMPFILE $VE_DUMP/Dump.$CTID
else
    echo "No dump file found"
fi

if [ "x"$DELETE_BACKUP_SNAPSHOT == "xyes" ]; then
    echo "Deleting backup snapshot.."
    vzctl snapshot-switch $CTID --id $BACKUP_ID
    vzctl snapshot-delete $CTID --id $BACKUP_ID
fi

vzlist $CTID
