2016-10-20 makss

	* Added local and global config
	* New options for restore: ip, hostname, description
	* Change options vzprestore.sh
	* Removed --ttl option
	* Minor improvements

2015-11-18 Andreas Faerber <af@maeh.org>

	* Added notice about the --ttl option to be removed beginning of
	  December as it's implementation is currently unsafe
	* Removed --ttl option from usage

2015-06-23 Andreas Faerber <af@maeh.org>

	* Added option "--compact" to compact a container before it is backed
          up
	* Redirect possible error message to /dev/null in vzprestore.sh in case
	  there is no additional configuration in the dump directory. This is
	  not an error for the restore process.

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
