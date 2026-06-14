#!/bin/bash

# ---Variables---
  DEST_IP="192.168.1.20"
  DEST_DIR="/backup/server1"
  EXDEST_DIR="/mnt/ebackup/server1"
  DEST_USER="root"
  SOURCE_DIR=("/etc" "/home" "/srv" "/var/named")
  LOG_FILE="/var/log/backup.log"

  DATE=$(date +%Y-%m-%d_%H%M%S)
  BACKUP_NAME="server1_backup_${DATE}.tar.gz"
  STAGING="/tmp/${BACKUP_NAME}"


#-----First log entry------
  
  echo "Backup started at $DATE" >> "$LOG_FILE"


#-----Creating a Staging file in /tmp------

  tar -czf $STAGING ${SOURCE_DIR[@]}

  if [ $? -eq 0 ]; then
       echo "Archive Create: $STAGING" >> "$LOG_FILE"
  else
       echo "ERROR: tar file faile stopping." >> "$LOG_FILE"
       exit 1
  fi 

#----- Sending this file to Server2---------

  rsync -a "$STAGING" "${DEST_USER}@${DEST_IP}:${DEST_DIR}/" >> "$LOG_FILE" 2>&1

  if [ $? -eq 0 ]; then
       echo "File sent succesfully." >> "$LOG_FILE"
  else
       echo "ERROR: Send Failed." >> "$LOG_FILE"
       exit 1
   fi

#----- Sending this file to Server2---------

  rsync -a "$STAGING" "${DEST_USER}@${DEST_IP}:${EXDEST_DIR}/" >> "$LOG_FILE" 2>&1

  if [ $? -eq 0 ]; then
       echo "File sent succesfully." >> "$LOG_FILE"
  else
       echo "ERROR: Send Failed." >> "$LOG_FILE"
       exit 1
   fi


# ----- Delete temp file from /tmp -----
  rm -f $STAGING
  echo "Temp file deleted." >> "$LOG_FILE"

  echo "Backup finished." >> "$LOG_FILE"
