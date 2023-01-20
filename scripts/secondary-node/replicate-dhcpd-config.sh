#!/bin/bash

#  _____ _  __
# |  ___| |/ /  Finn Krestel, 2023.
# | |_  | ' /   https://github.com/FinnKrestel
# |  _| | . \
# |_|   |_|\_\  /usr/local/lib/dhcpd/replicate-dhcpd-config.sh
#
# Pulls the current dhcpd.example.net.conf file from the primary node,
# compares its md5sum with the md5sum of the current dhcpd.example.net.conf file on the secondary node,
# and initiates an update and restart of the service when neccessary.

# Options
SSH_CMD="ssh"
SSH_HOST="node-01"
SSH_PORT="22"
SSH_USER="dhcpd-repl"
SSH_PRIVATE_KEY="/root/dhcpd/dhcpd-repl.rsa"
CONFIG_FILE="/etc/dhcp/dhcpd.exmaple.net.conf"

# Please do not change!
SCRIPT_NAME=$(basename $0)
FILE_CHECK="${CONFIG_FILE}.md5"
MD5_CURRENT=$(cat "$FILE_CHECK")
MD5_NEW=""

/usr/bin/rsync --rsync-path="sudo rsync" -XAavz -e "${SSH_CMD} -p ${SSH_PORT} -i ${SSH_PRIVATE_KEY}" --delete-after ${SSH_USER}@${SSH_HOST}:${CONFIG_FILE} ${CONFIG_FILE} > /dev/null 2>&1

MD5_NEW=$(/usr/bin/md5sum ${CONFIG_FILE} | awk '{print $1}')

if [ "$MD5_NEW" != "$MD5_CURRENT" ]; then
  logger -p local1.notice -t $SCRIPT_NAME -i "dhcpd configuration on master changed, restarting dhcpd (Current md5sum: $MD5_CURRENT / New md5sum: $MD5_NEW)"
  # Check config before reloading
  /usr/sbin/dhcpd -t > /dev/null 2>&1
  RC=$?
  if [ "$RC" -eq 0 ]; then
    systemctl restart isc-dhcp-server
    /usr/bin/md5sum ${CONFIG_FILE} | awk '{print $1}' > $FILE_CHECK
  else
    logger -p local1.warning -t $SCRIPT_NAME -i "WARNING: configuration check failed, will NOT restart dhcpd!"
  fi
fi
# Can be turned on, but could spam the log with "OK" messages
#else
#  echo "Config unchanged, no restart required"
#fi