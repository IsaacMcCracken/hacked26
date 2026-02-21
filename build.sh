#!/bin/bash

STATUS_FILE="/tmp/vizcode_build_status"

echo "BUILDING" > "$STATUS_FILE"

if [ -d $PWD/build/ ]; then
    rm -rf build
fi

mkdir build && cd build
cmake ..
make -j$(nproc)
echo "FINISHED BUILDING - CURRENTLY IN $PWD"

echo "DONE" > "$STATUS_FILE"
