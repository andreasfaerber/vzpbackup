2015-06-23 Andreas Faerber <af@maeh.org>

	* Added option "--compact" to compact a container before it is backed
          up

2015-06-22 Andreas Faerber <af@maeh.org>

	* Added option(s) to compress the archive through tar (tgz, tbz, txz)

2014-11-13 Andreas Faerber <af@maeh.org>

        * Merged pull request from renoguyon (Thank you!):
          New options : work-directory and time to live

2014-08-26 Andreas Faerber <af@maeh.org>

	* Output "BACKUP FILE: <Path to Backup created>" to allow further
	  processing after the vzpbackup finished

2014-08-25 Andreas Faerber <af@maeh.org>

	* Backup all container configuratin files in /etc/vz/conf/

	  vzpbackup and vzprestore now backup and restore all files related to
          the configuration of the CTID being backed up (/etc/vz/conf/$CTID.*).
