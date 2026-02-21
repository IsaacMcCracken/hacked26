#!/bin/bash

FILE_TO_TRANSFER="RP2040_Zero_Project.uf2"
TARGET_LABEL="RPI-RP2"
STATUS_FILE="/tmp/vizcode_flash_status"

echo "WAITING_FOR_RPI" > "$STATUS_FILE"
echo "PLEASE PLUG IN RPI WHILE HOLDING DOWN BOOT BUTTON"
while true; do
    MOUNT_POINT=$(lsblk -rn -o MOUNTPOINT -d /dev/disk/by-label/"$TARGET_LABEL" 2>/dev/null)

    if [ -n "$MOUNT_POINT" ]; then
        echo "MOUNT POINT: $MOUNT_POINT"

        echo "TRANSFERRING $FILE_TO_TRANSFER..."
        cp "build/$FILE_TO_TRANSFER" "$MOUNT_POINT/"

        echo "TRANSFER COMPLETE. RPI WILL REBOOT"
        break
    fi
    sleep 1
done

rm -rf generated
echo "REMOVED generated/"

echo "DONE" > "$STATUS_FILE"
