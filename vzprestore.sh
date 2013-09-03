#!/bin/sh
#
# vzploorestore.sh
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

##
## VARIABLES
##

TIMESTAMP=`date '+%Y%m%d%H%M%S'`

## VARIABLES END

for i in "$@"
do
case $i in
    --help)
    echo "Usage: $0 --archive=<Filename> --container=<CTID to restore to> [--confirm=<yes/no>]"
    echo "Defaults:"
    echo -e "Archive:\t\tNONE"
    echo -e "Container:\t\tNONE"
    exit 0;
    ;;
    --archive=*)
    ARCHIVE=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --container=*)
    CONTAINER=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --confirm=*)
    CONFIRM=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    *)
    # Parse CTIDs here
    ;;
esac
done

ARC_EXT=${ARCHIVE##*.}

if [ -z $ARCHIVE -o -z $CONTAINER ]; then
    echo "Usage: $0 --archive=<Filename> --container=<CTID to restore to> [--confirm=<yes/no>]"
    echo "Defaults:"
    echo -e "Archive:\t\tNONE" 
    echo -e "Container:\t\tNONE"
    echo
    echo "You need to give at least --archive and --container as arguments"
    exit 0;
fi

if [ ! -f $ARCHIVE ]; then
    echo "Archive $ARCHIVE does not exist or is inaccessible"
    exit 1;
fi

echo -e "Archive to restore:\t\t$ARCHIVE"
echo -e "Container to restore to:\t\t$CONTAINER"
echo -e "Confirm restore:\t\t$CONFIRM"
echo

CTID=$CONTAINER
ID=$(uuidgen)
VE_PRIVATE=$(VEID=$CTID; source /etc/vz/vz.conf; echo $VE_PRIVATE)
VE_ROOT=$(VEID=$CTID; source /etc/vz/vz.conf; echo $VE_ROOT)
VE_DUMP=$(VEID=$CTID; source /etc/vz/vz.conf; echo $DUMPDIR)

echo "Pre-Restore Checks.."
echo -n "Checking if container private directory ($VE_PRIVATE) already exists.."

if [ -d $VE_PRIVATE ]; then
    echo "yes, aborting"
    exit 0;
else
    echo "no"
    echo "$VE_PRIVATE directory will be created during restore"
fi

echo -n "Checking if container root directory ($VE_ROOT) already exists.."

if [ -d $VE_ROOT ]; then
    echo "yes, aborting"
    exit 0;
else
    echo "no"
    echo "$VE_ROOT directory will be created during restore"
fi

echo -n "Checking if container config file (/etc/vz/conf/$CTID.conf) already exists.."

if [ -d "/etc/vz/conf/$CTID.conf" ]; then
    echo "yes, aborting"
    exit 0;
else
    echo "no"
    echo "/etc/vz/conf/$VEID.conf will be restored from backup"
fi

echo
echo "Actions taken for restore:"

echo "mkdir $VE_ROOT"
echo "mkdir $VE_PRIVATE"
echo "cd $VE_PRIVATE"
echo "Extract backup archive into $VE_PRIVATE"
echo "Create container config /etc/vz/conf/$CTID.conf"
echo

if [ "x"$CONFIRM == "xyes" ]; then
    read -p "Confirm restore (yes/no): " INPUT
    if [ "x"$INPUT != "xyes" ]; then
        echo "Exiting.."
        exit 0;
    fi
fi

echo "Creating directory $VE_ROOT"
mkdir $VE_ROOT

echo "Creating direcotry $VE_PRIVATE"
mkdir $VE_PRIVATE

echo "cd into $VE_PRIVATE"
cd $VE_PRIVATE

echo "Extracting backup archive:"
if [ $ARC_EXT == "gz" ]; then
    TAR_ARGS="-zxvf"
else
    TAR_ARGS="-xvf"
fi
tar $TAR_ARGS $ARCHIVE

SRC_VE_CONF=$(ls -1 dump/*.ve.conf)
echo "SRC VE CONF: $SRC_VE_CONF"
mv $SRC_VE_CONF /etc/vz/conf/$CTID.conf

# Look for possible dump
DUMPFILE=${SRC_VE_CONF%.*.*}
echo DUMPFILE: $DUMPFILE
if [ -f $DUMPFILE ]; then
    echo "Found possible dump file.. moving it to $VE_DUMP"
    mv $DUMPFILE $VE_DUMP/Dump.$CTID
else
    echo "No dump file found"
fi


vzlist $CTID
