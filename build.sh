#!/bin/bash

FILE_TO_TRANSFER="RP2040_Zero_Project.uf2"
TARGET_LABEL="RPI-RP2"
STATUS_FILE="/tmp/vizcode_build_status"

echo "BUILDING" > "$STATUS_FILE"

if [ -d $PWD/build/ ]; then
    rm -rf build
fi

mkdir build && cd build
cmake ..
make -j$(nproc)
echo "FINSHED BUILDING  - CURRENTLY IN $PWD"

echo "WAITING_FOR_RPI" > "$STATUS_FILE"
echo "PLEASE PLUG IN RPI WHILE HOLDING DOWN BOOT BUTTON"
while true; do
    MOUNT_POINT=$(lsblk -rn -o MOUNTPOINT -d /dev/disk/by-label/"$TARGET_LABEL" 2>/dev/null)

    if [ -n "$MOUNT_POINT" ]; then
        echo "TRANSFERRING" > "$STATUS_FILE"
        echo "MOUNT POINT: $MOUNT_POINT"
        
        echo "TRANSFERRING $FILE_TO_TRANSFER..."
        cp "$FILE_TO_TRANSFER" "$MOUNT_POINT/"
        
        echo "TRANSFER COMPLLETE. RPI WILL REBOOT"
        break
    fi
    sleep 1
done

echo "$PWD"
cd ..
rm -rf build
rm -rf generated
echo "REMOVED build/ and generated/"

echo "DONE" > "$STATUS_FILE"
