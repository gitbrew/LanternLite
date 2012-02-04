SDKVER?=5.0
SDK=/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(SDKVER).sdk/
CC:=$(wildcard /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/arm-apple-darwin10-*gcc*)
CFLAGS=-Wall -isysroot $(SDK)
CFLAGS_IOKIT=$(CFLAGS) -framework IOKit -framework CoreFoundation -framework Security -O3 -I.

all: IOKit device_infos restored_external bruteforce

IOKit:
	ln -s /System/Library/Frameworks/IOKit.framework/Versions/Current/Headers IOKit

device_infos: device_infos.c device_info.c IOAESAccelerator.c AppleEffaceableStorage.c AppleKeyStore.c bsdcrypto/pbkdf2.c bsdcrypto/sha1.c bsdcrypto/key_wrap.c bsdcrypto/rijndael.c util.c IOKit.c registry.c
	$(CC) $(CFLAGS_IOKIT) -o $@ $^
	./ldid -S $@
	mv -f $@ ../Resources/RamdiskFiles/

restored_external: restored_external.c device_info.c remote_functions.c plist_server.c AppleKeyStore.c AppleEffaceableStorage.c IOKit.c IOAESAccelerator.c util.c registry.c AppleKeyStore_kdf.c bsdcrypto/pbkdf2.c bsdcrypto/sha1.c bsdcrypto/rijndael.c bsdcrypto/key_wrap.c
	$(CC) $(CFLAGS_IOKIT) -o $@ $^
	./ldid -Skeystore_device.xml $@
	mv -f $@ ../Resources/RamdiskFiles/

bruteforce: systemkb_bruteforce.c AppleKeyStore.c AppleEffaceableStorage.c IOKit.c IOAESAccelerator.c util.c registry.c AppleKeyStore_kdf.c bsdcrypto/pbkdf2.c bsdcrypto/sha1.c bsdcrypto/rijndael.c bsdcrypto/key_wrap.c device_info.c
	$(CC) $(CFLAGS_IOKIT) -o $@ $^
	./ldid -Skeystore_device.xml $@
	mv -f $@ ../Resources/RamdiskFiles/

clean:
	rm -f ../Resources/RamdiskFiles/bruteforce ../Resources/RamdiskFiles/restored_external ../Resources/RamdiskFiles/device_infos

rebuild: clean all
