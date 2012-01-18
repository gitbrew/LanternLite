UI based tool to perform various imaging tool for iOS devices.

The following functionality has been implemented:

- Physical imaging of data partition over USB
- Bruteforcing simple passcode if present on device
- Recovering device keys necessary to decrypt data partition
- Decrypting data partition

Requirements:

* LanternLite.pkg (found in downloads section) - also installs python deps
* redsn0w 0.9.9b8 (link: https://sites.google.com/a/iphone-dev.com/files/home/redsn0w_mac_0.9.9b8.zip)
* iOS 5.0 IPSW for your device (individual links below for supported devices)

iOS 5.0 download links:

- iPod Touch 3G: http://appldnld.apple.com/iPhone4/061-8360.20111012.New3w/iPod3,1_5.0_9A334_Restore.ipsw
- iPod Touch 4G: http://appldnld.apple.com/iPhone4/061-9622.20111012.Evry3/iPod4,1_5.0_9A334_Restore.ipsw
- iPhone 3GS: http://appldnld.apple.com/iPhone4/041-8356.20111012.SQRDT/iPhone2,1_5.0_9A334_Restore.ipsw
- iPhone 4 (GSM - AT&T): http://appldnld.apple.com/iPhone4/041-8358.20111012.FFc34/iPhone3,1_5.0_9A334_Restore.ipsw
- iPhone 4 (CDMA - Verizon): http://appldnld.apple.com/iPhone4/041-9743.20111012.vjhfp/iPhone3,3_5.0_9A334_Restore.ipsw
- iPad 1: http://appldnld.apple.com/iPhone4/041-8357.20111012.DTOrM/iPad1,1_5.0_9A334_Restore.ipsw

Instructions:

1) Download redsn0w and unzip. Move redsn0w application bundle (not the whole .zip flie) to the desktop.

2) Download the IPSW for your device and place it on the desktop.

3) Run LanternLite5.0.pkg and install. Continue with the rest of this process once you've logged out and back in.

4) Run app.