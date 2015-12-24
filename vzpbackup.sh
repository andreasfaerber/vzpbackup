#!/bin/bash
#
# vzpbackup.sh
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

SUSPEND=no
BACKUP_DIR=/store/vzpbackup
WORK_DIR=/store/vzpbackup
COMPRESS=no
COMPACT=0
TTL=0
IOLIMIT=

##
## VARIABLES
##

TIMESTAMP=`date '+%Y%m%d%H%M%S'`
VZLIST_CMD=/usr/sbin/vzlist
VZCTL_CMD=/usr/sbin/vzctl
EXCLUDE=""

## VARIABLES END

## FUNCTIONS

contains() {
    string="$1"
    substring="$2"

    case "$string" in
        *"$substring"*)
            return 1
        ;;
        *)
            return 0
        ;;
    esac

    return 0
}

## FUNCTIONS END

for i in "$@"
do
case $i in
    --help)
		echo "Usage: $0 [--suspend=<yes/no>] [--backup-dir=<Backup-Directory>] [--work-dir=<Temp-Directory>] [--compress=<no/pz/bz/pbz/tbz/gz/tgz/xz/txz>] [--ttl=<Days to live>] [--compact] [--all] <CTID> <CTID>"
		echo "Defaults:"
		echo -e "SUSPEND:\t\t$SUSPEND"
		echo -e "BACKUP_DIR:\t\t$BACKUP_DIR"
    		echo -e "WORK_DIR:\t\t$WORK_DIR"
		echo -e "COMPRESS:\t\t$COMPRESS"
    		echo -e "TTL:\t\t\t$TTL"
    		echo -e "COMPACT:\t\t$COMPACT"
    		echo -e "IOLIMIT:\t\t$IOLIMIT"
		exit 0;
    ;;
    --suspend=*)
    	SUSPEND=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --exclude=*)
    	EXCLUDE="$EXCLUDE `echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
    ;;
    --backup-dir=*)
    	BACKUP_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      	WORK_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --work-dir=*)
      	WORK_DIR=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --compress=*)
		COMPRESS=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
	;;
    --ttl=*)
    	TTL=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --compact)
        COMPACT=1
    ;;
    --iolimit=*)
    	IOLIMIT=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
    --all)
    	CTIDS=`$VZLIST_CMD -a -Hoctid`
    ;;
    *)
	# Parse CTIDs here
        CTIDS=$CTIDS" "$i
    ;;
esac
done

echo -e "SUSPEND: \t\t$SUSPEND"
echo -e "BACKUP_DIR: \t\t$BACKUP_DIR"
echo -e "WORK_DIR: \t\t$WORK_DIR"
echo -e "COMPRESS: \t\t$COMPRESS"
echo -e "COMPACT: \t\t$COMPACT"
echo -e "IOLIMIT: \t\t$IOLIMIT"
echo -e "BACKUP TTL: \t\t$TTL"
echo -e "CTIDs to backup: \t\t$CTIDS"
echo -e "EXCLUDE CTIDs: \t\t$EXCLUDE"

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

contains "$EXCLUDE" $CTID
CONTAINS=$?

if [ $CONTAINS -eq 1 ]; then
    echo "Excluding CTID $CTID .."
    continue;
fi

# Check if the VE exists
if grep -w "$CTID" <<< `$VZLIST_CMD -a -Hoctid` &> /dev/null; then
        if [ $COMPACT == 1 ]; then
            echo "Compacting CTID: $CTID"
            $VZCTL_CMD compact $CTID > /tmp/vzpbackup_compact_$CTID_$TIMESTAMP.log
            echo "Compact log file: /tmp/vzpbackup_compact_$CTID_$TIMESTAMP.log"
        fi

	echo "Backing up CTID: $CTID"

	ID=$(uuidgen)
	VE_PRIVATE=$(VEID=$CTID; source /etc/vz/vz.conf; source /etc/vz/conf/$CTID.conf; echo $VE_PRIVATE)
	echo $ID > $VE_PRIVATE/vzpbackup_snapshot

	# Take CT snapshot with parameters
	$VZCTL_CMD snapshot $CTID --id $ID $CMDLINE

	# Backup configuration additional configuration files (/etc/vz/conf/$CTID.*)

        echo "Copying config files: "
        for f in $(ls -1 /etc/vz/conf/$CTID.*)
        do
            CONF_EXT=${f##*.}
            cp $f "$VE_PRIVATE/dump/{$ID}.ve.$CONF_EXT"
            echo $f
        done

	# Copy the backup somewhere safe
	# We copy the whole directory which then also includes
	# a possible the dump (while being suspended) and container config
	cd $VE_PRIVATE
	HNAME=`$VZLIST_CMD -Hohostname $CTID`

        TAR_CMD=
        ARCHIVE_FILENAME=

        if [ "$COMPRESS" == "tgz" ]; then
            TAR_CMD="tar -zcvf"
            ARCHIVE_FILENAME=$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.gz
            BACKUP_PATH="."
            COMPRESS_SUFFIX=gz
        elif [ "$COMPRESS" == "tbz" ]; then
            TAR_CMD="tar -jcvf"
            ARCHIVE_FILENAME="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.bz2"
            BACKUP_PATH="."
            COMPRESS_SUFFIX=bz2
        elif [ "$COMPRESS" == "txz" ]; then
            TAR_CMD="tar -Jcvf"
            ARCHIVE_FILENAME="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.xz"
            BACKUP_PATH="."
            COMPRESS_SUFFIX=xz
        elif [ "$COMPRESS" == "pz" ]; then
	    TAR_CMD="tar --use-compress-program=pigz -cvf"
            ARCHIVE_FILENAME="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.gz"
            BACKUP_PATH="."
            COMPRESS_SUFFIX=gz
        elif [ "$COMPRESS" == "pbz" ]; then
            TAR_CMD="tar --use-compress-program=pbzip2 -cvf"
            ARCHIVE_FILENAME="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.bz2"
            BACKUP_PATH="."
            COMPRESS_SUFFIX=bz2
        else
            TAR_CMD="tar -cvf"
            ARCHIVE_FILENAME="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar"
            BACKUP_PATH="."
            COMPRESS_SUFFIX=
        fi

        # Execute tar
        if [ -z "$IOLIMIT" ]; then
            echo "No IO limiting.."
            $TAR_CMD $ARCHIVE_FILENAME $BACKUP_PATH
        else
            echo "IO limit of $IOLIMIT active"
            $TAR_CMD - $BACKUP_PATH | pv -L $IOLIMIT > $ARCHIVE_FILENAME
        fi

        echo "Removing backup config files: "
        for f in $(ls -1 $VE_PRIVATE/dump/{$ID}.ve.*)
        do
            ls -la "$f"
            rm "$f"
        done

	# Compress the archive if wished
	if [ "$COMPRESS" != "no" ]; then
                if [ $COMPRESS == "tgz" -o $COMPRESS="tbz" -o $COMPRESS="txz" ]; then
                    echo -n "Compressing the backup archive "
                    COMPRESS_SUFFIX=""
		fi
		if [ "$COMPRESS" == "bz" ]; then
			echo "with bzip2"
                        CMD="bzip2"
                        COMPRESS_SUFFIX="bz2"
		elif [ "$COMPRESS" == "gz" ]; then
			echo "with gzip"
                        CMD="gzip"
                        COMPRESS_SUFFIX="gz"
		elif [ "$COMPRESS" == "xz" ]; then
			echo "with xz"
                        CMD="xz --compress"
                        COMPRESS_SUFFIX="xz"
		fi
                if [ -r $WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar ]; then
                    $CMD $WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar
                    BACKUP_FILE="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.$COMPRESS_SUFFIX"
                else
                    if [ $COMPRESS == "tgz" -o $COMPRESS="tbz" -o $COMPRESS="txz" ]; then
                        echo "$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar not found!"
                    fi
                fi
        else
            BACKUP_FILE="$WORK_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar"
	fi
  
  # Move file from temp directory to backup directory
  
  if [ "$BACKUP_DIR" != "$WORK_DIR" ]; then
    echo "Moving backup file"
  
    if [ "$COMPRESS_SUFFIX" != "" ]; then
      FINAL_FILE="$BACKUP_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar.$COMPRESS_SUFFIX"
    else
      FINAL_FILE="$BACKUP_DIR/vzpbackup_${CTID}_${HNAME}_${TIMESTAMP}.tar"
    fi
    
    mv $BACKUP_FILE $FINAL_FILE
    BACKUP_FILE="$FINAL_FILE"
  fi
  
  # Delete old backups
  
  if [ "$TTL" -gt 0 ]; then
    echo "Deleting old backup files..."
    find $BACKUP_DIR/* -mtime +${TTL} -exec rm {} \;
  fi
  

        echo "BACKUP FILE: $BACKUP_FILE"
        ls -la $BACKUP_FILE

	# Delete (merge) the snapshot
	$VZCTL_CMD snapshot-delete $CTID --id $ID
else
	echo "WARNING: No CT found for ID $CTID. Skipping..."
fi

done
