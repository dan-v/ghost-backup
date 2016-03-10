#!/bin/bash
# ------------------------------------------------------------------
#  ghost_backup.sh
#      export ghost settings and data through web ui and backup
#      content folder through ssh.
# ------------------------------------------------------------------
VERSION=0.2.0
SUBJECT=ghost-backup

# --- Variables ---------------------------------------------------------
dns="" # domain name used for blog
web_login_user="" # admin user login for Ghost (url encoded)
web_login_pass="" # admin user pass for Ghost
header_client_secret="" #the client_secret parameter passed in the http header (random for every ghost install)
remote_content_backup_path="" # full path to Ghost content directory (e.g. /home/ghost/content)
ssh_login_user="" # ssh user with access to remote_content_backup_path
base_url="https://${dns}"
ssh_host="${dns}"
signin_url="${base_url}/ghost/api/v0.1/authentication/token"
export_url="${base_url}/ghost/api/v0.1/db/"
backup_export_filename="ghost-backup-$(date +%m-%d-%y).json"
backup_content_filename="ghost-backup-content-$(date +%m-%d-%y).tar.gz"

# --- Locks -------------------------------------------------------------
LOCK_FILE=/tmp/$SUBJECT.lock
if [ -f "$LOCK_FILE" ]; then
   echo "Script is already running"
   exit 1
fi

trap "rm -f $LOCK_FILE" EXIT
touch $LOCK_FILE

# checks
if [[ -z "$dns" ]]; then
  echo "Need to set 'dns' in this script. Exiting."
  exit 1
fi
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

echo -e "\n--- Login to Ghost blog\n"
login_response=$(/usr/local/bin/curl -k -s --data "grant_type=password&username=${web_login_user}&password=${web_login_pass}&client_id=ghost-admin&client_secret=${header_client_secret}" $signin_url | awk -F'"' '{print $4}');
if [[ -z "$login_response" ]]; then
  echo "Failed to get access token from login. Exiting."
  exit 1
fi

echo -e "\n--- Export blog settings and data\n"
export_response=$(/usr/local/bin/curl -k -s -w "%{http_code}" ${export_url}?access_token=$login_response -o $backup_export_filename)
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
