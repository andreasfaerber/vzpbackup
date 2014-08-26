2014-08-26 Andreas Faerber <af@maeh.org>

	* Output "BACKUP FILE: <Path to Backup created>" to allow further
	  processing after the vzpbackup finished

2014-08-25 Andreas Faerber <af@maeh.org>

	* Backup all container configuratin files in /etc/vz/conf/

	  vzpbackup and vzprestore now backup and restore all files related to
          the configuration of the CTID being backed up (/etc/vz/conf/$CTID.*).
