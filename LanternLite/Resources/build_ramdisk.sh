#!/bin/bash

# build custom ramdisk (mostly from iphone-dataprotection)

BUNDLE_PATH=$1
IPSW_PATH=$2
PF_PATH=$3
MODEL=$4
RD=$5
KEY=$6
IV=$7

CRD="$MODEL.myramdisk.dmg" 
XPWNTOOL="$BUNDLE_PATH/xpwntool"
SSH_BUNDLE="$BUNDLE_PATH/ssh.tar.gz"
RD_TOOLS="$BUNDLE_PATH/RamdiskFiles"
  
unzip "$IPSW_PATH" "$RD" -d "$PF_PATH"

$XPWNTOOL "$PF_PATH/$RD" "$PF_PATH/unpacked.myramdisk.dmg" -k $KEY -iv $IV

hdiutil attach "$PF_PATH/unpacked.myramdisk.dmg"
  
#remove baseband files to free space
rm -rf /Volumes/ramdisk/usr/local/standalone/firmware/*
rm -rf /Volumes/ramdisk/usr/share/progressui/
tar -C /Volumes/ramdisk/ -xzP < $SSH_BUNDLE
rm /Volumes/ramdisk/bin/vdir
rm /Volumes/ramdisk/bin/egrep
rm /Volumes/ramdisk/bin/grep

cp "$RD_TOOLS/restored_external" /Volumes/ramdisk/usr/local/bin
cp "$RD_TOOLS/bruteforce" "$RD_TOOLS/device_infos" /Volumes/ramdisk/var/root

hdiutil eject /Volumes/ramdisk

$XPWNTOOL "$PF_PATH/unpacked.myramdisk.dmg" "$PF_PATH/$MODEL.myramdisk.dmg" -k $KEY -iv $IV -t "$PF_PATH/$RD"
  
rm "$PF_PATH/unpacked.myramdisk.dmg"
rm "$PF_PATH/$RD"
