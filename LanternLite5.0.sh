#!/bin/bash

# script to temporarily handle patching files and booting iOS device
# this functionality will be integrated into the GUI soon

set -e
set -u

LL_PATH="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LL_FILES_PATH="Library/Application Support/LanternLite"
LL_APP_NAME="LanternLite5.0.app"
PF_DIR="patched"
TCPRELAY_PID=""

IPOD31_IPSW="iPod3,1_5.0_9A334_Restore.ipsw"
IPOD41_IPSW="iPod4,1_5.0_9A334_Restore.ipsw"
IPHONE21_IPSW="iPhone2,1_5.0_9A334_Restore.ipsw"
IPHONE31_IPSW="iPhone3,1_5.0_9A334_Restore.ipsw"
IPHONE33_IPSW="iPhone3,3_5.0_9A334_Restore.ipsw"
IPAD11_IPSW="iPad1,1_5.0_9A334_Restore.ipsw"

IPOD31_MODEL="n18ap"
IPOD41_MODEL="n81ap"
IPHONE21_MODEL="n88ap"
IPHONE31_MODEL="n90ap"
IPHONE33_MODEL="n92ap"
IPAD11_MODEL="k48ap"

patch_kernel ()
{
  IPSW=$1
  MODEL=$2
  
  # Make sure we have the right IPSW
  echo "Checking for $IPSW in $HOME/Desktop/"
  if [ ! -f "$HOME/Desktop/$IPSW" ]
    then
      echo "$IPSW not found"
      exit
  fi
  echo "Creating directory to hold patched files"
  mkdir -p "$HOME/$LL_FILES_PATH/$PF_DIR"
  if [ ! -d "$HOME/$LL_FILES_PATH/$PF_DIR" ]
    then
      echo "Unable to create $HOME/$LL_FILES_PATH/$PF_DIR"
      exit
  fi
  echo "Grabbing Keys.plist"
  cp "$HOME/Desktop/redsn0w.app/Contents/MacOS/Keys.plist" "$HOME/$LL_FILES_PATH/$PF_DIR"
  if [ ! -f "$HOME/$LL_FILES_PATH/$PF_DIR/Keys.plist" ]
    then
      echo "Failed to copy Keys.plist"
      exit
  fi
  echo "Patching kernel"
  RD_BUILD_OPTS="$( python -B "$LL_PATH/$LL_APP_NAME/Contents/Resources/PythonScripts/kernel_patcher.py" "$HOME/Desktop/$IPSW" $MODEL "$HOME/$LL_FILES_PATH/$PF_DIR" )"
  if [ "$( echo "$RD_BUILD_OPTS" | awk '{ print $1 }' )" != "OK" ]
    then
      echo "Kernel patching failed"
      exit
  fi

  RD="$( echo "$RD_BUILD_OPTS" | awk '{ print $3 }' )"
  KEY="$( echo "$RD_BUILD_OPTS" | awk '{ print $4 }' )"
  IV="$( echo "$RD_BUILD_OPTS" | awk '{ print $5 }' )"

  build_rd $IPSW $MODEL $RD $KEY $IV
}

# mostly from iphone-dataprotection
build_rd ()
{
  IPSW=$1
  MODEL=$2
  RD=$3
  KEY=$4
  IV=$5
  
  CRD="$MODEL.myramdisk.dmg"
  XPWNTOOL="$LL_PATH/$LL_APP_NAME/Contents/Resources/xpwntool"
  SSH_BUNDLE="$LL_PATH/$LL_APP_NAME/Contents/Resources/ssh.tar.gz"
  RD_TOOLS="$LL_PATH/$LL_APP_NAME/Contents/Resources/RamdiskFiles"

  if [ ! -f $XPWNTOOL ]
    then
      echo "xpwntool not found"
      exit
  fi
  if [ ! -f $SSH_BUNDLE ]
    then
      echo "ssh bundle not found"
      exit
  fi
  
  unzip "$HOME/Desktop/$IPSW" "$RD" -d "$HOME/$LL_FILES_PATH/$PF_DIR" > /dev/null 2>&1

  $XPWNTOOL "$HOME/$LL_FILES_PATH/$PF_DIR/$RD" "$HOME/$LL_FILES_PATH/$PF_DIR/unpacked.myramdisk.dmg" -k $KEY -iv $IV > /dev/null 2>&1

  hdiutil attach "$HOME/$LL_FILES_PATH/$PF_DIR/unpacked.myramdisk.dmg" > /dev/null 2>&1

  #remove baseband files to free space
  rm -rf /Volumes/ramdisk/usr/local/standalone/firmware/*
  rm -rf /Volumes/ramdisk/usr/share/progressui/
  tar -C /Volumes/ramdisk/ -xzP < $SSH_BUNDLE
  rm /Volumes/ramdisk/bin/vdir
  rm /Volumes/ramdisk/bin/egrep
  rm /Volumes/ramdisk/bin/grep

  cp "$RD_TOOLS/restored_external" /Volumes/ramdisk/usr/local/bin
  cp "$RD_TOOLS/bruteforce" "$RD_TOOLS/device_infos" /Volumes/ramdisk/var/root

  hdiutil eject /Volumes/ramdisk > /dev/null 2>&1

  $XPWNTOOL "$HOME/$LL_FILES_PATH/$PF_DIR/unpacked.myramdisk.dmg" "$HOME/$LL_FILES_PATH/$PF_DIR/$MODEL.myramdisk.dmg" -k $KEY -iv $IV -t "$HOME/$LL_FILES_PATH/$PF_DIR/$RD" > /dev/null 2>&1
  
  rm "$HOME/$LL_FILES_PATH/$PF_DIR/unpacked.myramdisk.dmg"
  rm "$HOME/$LL_FILES_PATH/$PF_DIR/$RD"

  echo "$CRD created"
}

launch_redsn0w ()
{
  IPSW=$1
  MODEL=$2

  echo "Launching redsn0w"
  echo ""
  echo "*** Be sure to click the \"Cancel\" button in redsn0w once redsn0w reports \"Done!\" ***"
  echo ""
  "$HOME/Desktop/redsn0w.app/Contents/MacOS/redsn0w" \
    -i "$HOME/Desktop/$IPSW" \
    -r "$HOME/$LL_FILES_PATH/$PF_DIR/$MODEL.myramdisk.dmg" \
    -k "$HOME/$LL_FILES_PATH/$PF_DIR/$MODEL.kernelcache" \

  echo "Waiting 45 seconds for device to boot"
  sleep 45
  echo "Device should now have finished booting"
  echo ""
}

launch_lanternlite ()
{
  echo "Launching tcprelay"
  python -B "$LL_PATH/$LL_APP_NAME/Contents/Resources/PythonScripts/tcprelay.py" -t 22:47499 1999:1999 > /dev/null 2>&1 &
  
  if [ "$TCPRELAY_PID" == "" ]
    then
      # Launch tcprelay and make sure we take care of it when script is terminated
      TCPRELAY_PID="$( ps -U $USER | grep "tcprelay.py" | grep -v grep | awk '{ print $1 }' )"
      trap "kill $TCPRELAY_PID; exit" INT TERM EXIT
  fi

  echo "Launching LanternLite"
  "$LL_PATH/$LL_APP_NAME/Contents/MacOS/LanternLite" > /dev/null 2>&1
  
  clear
  echo "LanternLite has completed"
  echo ""
  read -p "Press Enter to return to the main menu..."
  clear
}

# Make sure we have LanternLite and redsn0w
clear
echo "Please make sure the iOS 5.0 IPSW for your device and redsn0w are on your desktop."
echo ""
read -p "Press Enter to continue..."

echo "Checking for $LL_APP_NAME in $LL_PATH/"
if [ ! -d "$LL_PATH/$LL_APP_NAME" ]
  then
    echo "$LL_APP_NAME not found"
    exit
fi
echo "Checking for redsn0w in $HOME/Desktop/"
if [ ! -d "$HOME/Desktop/redsn0w.app" ]
  then
    echo "redsn0w not found"
    exit
fi

clear
echo "****************************************"
echo "*        LanternLite (iOS 4 & 5)       *"
echo "****************************************"
echo "*                                      *"
echo "*       iOS device imaging tools       *"
echo "*                                      *"
echo "****************************************"
echo ""

selection=""
until [ "$selection" = "0" ];
do
  echo "Please select the type of iOS device to be imaged:"
  echo ""
  echo "1) iPod Touch 3G"
  echo "2) iPod Touch 4G"
  echo "3) iPhone 3GS"
  echo "4) iPhone 4 (GSM - AT&T)"
  echo "5) iPhone 4 (CDMA - Verizon)"
  echo "6) iPad 1"
  echo ""
  echo "0) Exit"
  echo ""
  echo "Selection: "
  read selection

  case $selection in
  1 ) 
      clear
      patch_kernel $IPOD31_IPSW $IPOD31_MODEL
      launch_redsn0w $IPOD31_IPSW $IPOD31_MODEL
      launch_lanternlite
      ;;
  2 ) 
      clear
      patch_kernel $IPOD41_IPSW $IPOD41_MODEL
      launch_redsn0w $IPOD41_IPSW $IPOD41_MODEL
      launch_lanternlite
      ;;
  3 ) 
      clear
      patch_kernel $IPHONE21_IPSW $IPHONE21_MODEL
      launch_redsn0w $IPHONE21_IPSW $IPHONE21_MODEL
      launch_lanternlite
      ;;
  4 ) 
      clear
      patch_kernel $IPHONE31_IPSW $IPHONE31_MODEL
      launch_redsn0w $IPHONE31_IPSW $IPHONE31_MODEL
      launch_lanternlite
      ;;
  5 ) 
      clear
      patch_kernel $IPHONE33_IPSW $IPHONE33_MODEL
      launch_redsn0w $IPHONE33_IPSW $IPHONE33_MODEL
      launch_lanternlite
      ;;
  6 ) 
      clear
      patch_kernel $IPAD11_IPSW $IPAD11_MODEL
      launch_redsn0w $IPAD11_IPSW $IPAD11_MODEL
      launch_lanternlite
      ;;
  0 ) 
      clear
      echo "Goodbye."
      exit
      ;;
  * ) 
      clear
      echo "*** Please enter valid option (1-6 or 0) ***"
      echo ""
  esac
done