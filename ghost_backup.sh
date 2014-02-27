#!/bin/bash
# ------------------------------------------------------------------
#  ghost_backup.sh
#      export ghost settings and data through web ui and backup 
#      content folder through ssh.
# ------------------------------------------------------------------
VERSION=0.1.0
SUBJECT=ghost-backup

# --- Variables ---------------------------------------------------------
dns="" # domain name used for blog
web_login_user="" # admin user login for Ghost
web_login_pass="" # admin user pass for Ghost
remote_content_backup_path="" # full path to Ghost content directory (e.g. /home/ghost/content)
ssh_login_user="" # ssh user with access to remote_content_backup_path
base_url="https://${dns}"
ssh_host="${dns}"
signin_url="${base_url}/ghost/signin/"
export_url="${base_url}/ghost/api/v0.1/db/"
backup_export_filename="ghost-backup-$(date +%m-%d-%y).json"
backup_content_filename="ghost-backup-content-$(date +%m-%d-%y).tar.gz"
cookie_file=/tmp/cookie.txt

# --- Locks -------------------------------------------------------------
LOCK_FILE=/tmp/$SUBJECT.lock
if [ -f "$LOCK_FILE" ]; then
   echo "Script is already running"
   exit 1
fi

trap "rm -f $LOCK_FILE" EXIT
touch $LOCK_FILE

# checks
if [[ -z "$web_login_user" ]]; then
  echo "Need to set 'web_login_user' in this script. Exiting."
  exit 1
fi
if [[ -z "$web_login_pass" ]]; then
  echo "Need to set 'web_login_pass' in this script. Exiting."
  exit 1
fi
if [[ -z "$ssh_login_user" ]]; then
  echo "Need to set 'ssh_login_user' in this script. Exiting."
  exit 1
fi
if [[ -z "$remote_content_backup_path" ]]; then
  echo "Need to set 'remote_content_backup_path' in this script. Exiting."
  exit 1
fi

# --- Main Script -------------------------------------------------------
echo -e "\n---"
echo -e "- Ghost Backup Script v${VERSION}"
echo -e "---\n"

# first backup data and settings through UI
echo -e "\n--- Gather CSRF token from login page\n"
> $cookie_file
csrf_token=$(curl -s -k $signin_url --cookie-jar $cookie_file | awk -F\" '/csrf/{print $4}')
if [[ -z "$csrf_token" ]]; then
  echo "Failed to get csrf_token from $signin_url. Exiting."
  exit 1
fi

echo -e "\n--- Login to Ghost blog\n"
login_response=$(curl -k -s -o /dev/null -w "%{http_code}" --data "email=$web_login_user&password=$web_login_pass" $signin_url -c $cookie_file -b $cookie_file --header "X-CSRF-Token: $csrf_token")
if [ "$login_response" != "200" ]; then
  echo "Failed to login with provided credentials. Received HTTP response code $login_response. Exiting."
  exit 1
fi

echo -e "\n--- Export blog settings and data\n"
export_response=$(curl -k -s -w "%{http_code}" $export_url -c $cookie_file -b $cookie_file -o $backup_export_filename)
if [ "$export_response" != "200" ]; then
  echo "Failed to export data. Received HTTP response code $export_response. Exiting."
  exit 1
fi
echo -e "\n--- Successfully backed up settings and data to file '${backup_export_filename}'\n"

# second backup content folder (need to figure out ssh escaping)
echo -e "\n--- Backing up content folder over SSH\n"
backup=$(ssh ${ssh_login_user}@${ssh_host} \\"tar -zcvf - $remote_content_backup_path 2>/tmp/sshbackup\\" > ${backup_content_filename})
if [ $? -ne 0 ]; then
	echo "ERROR: Failed to backup content folder over SSH."
	exit 1
fi
echo -e "\n--- Successfully backed up content folder to '${backup_content_filename}'\n"

echo -e "\n--- Backup Finished\n"
