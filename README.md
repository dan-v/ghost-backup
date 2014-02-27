ghost-backup
============

Simple backup script for a self hosted Ghost blog. It should be run from an external host (not from the Ghost server itself). 
The script creates two backup files and dumps them into the current directory with datestamps.
* The first backup is a JSON file exported through the web interface containing blog settings and data
* The second backup is the Ghost content directory compressed into a file through an SSH connection 

How to run script:
* Edit ghost_backup.sh and fill in following variables:
<pre>
dns="" # domain name used for blog
web_login_user="" # admin user login for Ghost
web_login_pass="" # admin user pass for Ghost
remote_content_backup_path="" # full path to Ghost content directory (e.g. /home/ghost/content)
ssh_login_user="" # ssh user with access to remote_content_backup_path
</pre>
* Execute script: ./ghost_backup.sh

Cron example:
<pre>
0 1 * * * cd /home/user/backups/domain.com && /bin/bash /home/user/ghost_backup.sh
</pre>