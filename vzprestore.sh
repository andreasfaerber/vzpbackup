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
DELETE_BACKUP_SNAPSHOT=yes

##
## VARIABLES
##

VZPDATE=`date '+%Y-%m-%d %H:%M:%S'`
VZLIST_CMD=/usr/sbin/vzlist
VZCTL_CMD=/usr/sbin/vzctl
VZDIR=

## VARIABLES END

show_usage() {
	echo -e "--------------------------------------------------------------------
Usage: $0
\t[--ip=<New IP>]
\t[--hostname=<New Hostname>]
\t[--description=\"<New Description>\"]
\t[--vzdir=<Directory to restore VE_PRIVATE and VE_ROOT to>]
\t[--confirm=<yes/no>]
\t[--delete-backup-snapshot=<yes/no>]
\t<Filename> <CTID>

You need to give at least <Filename> and <CTID> as arguments
--------------------------------------------------------------------
Defaults:";
	show_param;
	echo "Note: Deleting the backup snapshot causes a switch to and a deletion
      of the snapshot taken during backup. Doing so will cause any
      running container to be rebooted. You will not be able to
      resume the container from a suspended state.";
}

show_param() {
	echo "---";
	echo -e "Filename:\t\t\t$ARCHIVE";
	echo -e "Restore to container:\t\t$CONTAINER";
	if [ ! -z "$VZIP" ]; then
		echo -e "New IP:\t\t\t\t$VZIP";
	fi
	if [ ! -z "$VZHOSTNAME" ]; then
		echo -e "New HOSTNAME:\t\t\t$VZHOSTNAME";
	fi
	if [ ! -z "$VZDESCRIPTION" ]; then
		echo -e "New DESCRIPTION:\t\t$VZDESCRIPTION";
	fi
	if [ "x"$VE_PRIVATE == "x" ]; then
		echo -e "Restoring VZ to:\t\tGlobal Default";
	else
		echo -e "Restoring VE_PRIVATE:\t\t$VE_PRIVATE";
		echo -e "Restoring VE_ROOT:\t\t$VE_ROOT";
	fi
	echo -e "Confirm restore:\t\t$CONFIRM";
	echo -e "Delete Backup Snapshot:\t\t$DELETE_BACKUP_SNAPSHOT";
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
    --ip=*)
    	VZIP=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --hostname=*)
    	VZHOSTNAME=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --description=*)
    	VZDESCRIPTION=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
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


if [ "x"$CONFIRM == "xyes" ]; then
    read -p "Confirm restore (yes/no): " INPUT
    if [ "x"$INPUT != "xyes" ]; then
        echo "Exiting.."
        exit 0;
    fi
fi

echo -e "\nCreating directory $VE_ROOT";
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

# New .conf
	CFG=`egrep -v '^(VE_ROOT|VE_PRIVATE)' $SRC_VE_CONF`;
	ADD="\n\n# Restored using vzpbackup at $VZPDATE from file '$ARCHIVE'\n";
	ADD+="VE_ROOT=$VE_ROOT\n";
	ADD+="VE_PRIVATE=$VE_PRIVATE\n";
	if [ ! -z "$VZHOSTNAME" ]; then
		CFG=`echo "$CFG" | egrep -v '^HOSTNAME'`;
		ADD+="HOSTNAME=\"$VZHOSTNAME\"\n";
	fi
	if [ ! -z "$VZDESCRIPTION" ]; then
		CFG=`echo "$CFG" | egrep -v '^DESCRIPTION'`;
		ADD+="DESCRIPTION=\"$VZDESCRIPTION\"\n";
	fi
	if [ ! -z "$VZIP" ]; then
		CFG=`echo "$CFG" | egrep -v '^IP_ADDRESS'`;
		ADD+="IP_ADDRESS=\"$VZIP\"\n";
	fi
	echo -e "$CFG$ADD" > /etc/vz/conf/$CTID.conf
	rm $SRC_VE_CONF;

# Restore other files with .vzprestore suffix
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
	$VZCTL_CMD snapshot-switch $CTID --id $BACKUP_ID
	$VZCTL_CMD snapshot-delete $CTID --id $BACKUP_ID
fi

$VZLIST_CMD $CTID
