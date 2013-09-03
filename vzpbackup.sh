#!/bin/sh
#
# vzploobackup.sh
#
# A script to backup the containers running on an OpenVZ host.
# The container needs to utilize ploop as disk storage.
# Traditional storage is not supported by this script.
# The backup can be taken while the container is running.
#
# The script is based on the information on the ploop wiki page
# (http://openvz.org/Ploop/Backup) and has been developed based
# on that information.
#
# After reading the command line arguments the script will create a
# snapshot of the ploop device and backup it (via tar) to a
# configurable directory. It will always include the config file
# of the container backed up.
#
# Author: Andreas Faerber, af@maeh.org

##
## DEFAULTS
## 

BACKUP_DIR=/store/vzpbackup/
SUSPEND=no
BACKUP_ARGS=

##
## VARIABLES
##

TIMESTAMP=`date '+%Y%m%d%H%M%S'`

## VARIABLES END

for i in "$@"
do
case $i in
    --help)
    echo "Usage: $0 [--suspend=<yes/no>] [--backup-dir=<Backup-Directory>] [--all] <CTID> <CTID>"
    echo "Defaults:"
    echo -e "BACKUP_DIR:\t\t$BACKUP_DIR"
    echo -e "SUSPEND:\t\t$SUSPEND"
    exit 0;
    ;;
    --suspend=*)
    SUSPEND=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --backup-dir=*)
    BACKUP_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --all)
    CTIDS=`vzlist -Hoctid`
    ;;
    *)
    # Parse CTIDs here
    CTIDS=$CTIDS" "$i
    ;;
esac
done

echo BACKUP_DIR: $BACKUP_DIR
echo SUSPEND: $SUSPEND
echo CTIDs to backup: $CTIDS

if [ "x$SUSPEND" != "xyes" ]; then
    CMDLINE="${CMDLINE} --skip-suspend"
fi
if [ -z "$CTIDS" ]; then
    echo ""
    echo "No CTs to backup (Either give CTIDs or --all on the commandline)"
    exit 0
fi

for i in $CTIDS
do

CTID=$i

echo "Backing up CTID: $CTID"

ID=$(uuidgen)
VE_PRIVATE=$(VEID=$CTID; source /etc/vz/vz.conf; source /etc/vz/conf/$CTID.conf; echo $VE_PRIVATE)
 
# Take CT snapshot with parameters
vzctl snapshot $CTID --id $ID $CMDLINE
 
# Copy the backup somewhere safe
# We copy the whole directory which then also includes
# a possible the dump (while being suspended) and container config
cd $VE_PRIVATE
HNAME=`vzlist -Hohostname $CTID`

tar cvf $BACKUP_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar .

# Delete (merge) the snapshot
vzctl snapshot-delete $CTID --id $ID

done
