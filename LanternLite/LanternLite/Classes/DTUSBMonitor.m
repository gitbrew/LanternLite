//
//	DTUSBMonitor.m
//
//	Created by Author on 7/03/11.
//	Copyright 2011 Katana Forensics, Inc. All rights reserved.
//	Adapted from Apple sample code.
//
//	Listen for device attached/remove notifications and report them to a delegate.
//	More than one instance of this class may be created as needed.
//
//	Use Case 1:
//	Instantiate and get a list of devices once, then release.
//	
//		DTUSBMonitor * usb = [[[DTUSBMonitor alloc] init] autorelease];
//		NSArray * iphones = [usb devicesMatchingVendor:0x05ac product:0x1294];
//		NSLog(@"iPhones: %@", iphones);
//
//	Use Case 2:
//	Instantiate and keep around, so we get notifications of plug/unplug
//
//		DTUSBMonitor * usb = [[DTUSBMonitor alloc] initWithVendor:0x05ac product:0 delegate:self];
//			(will get callbacks of usbDeviceAdded / usbDeviceRemoved for all Apple products - vendor 0x5ac)
//

#import "DTUSBMonitor.h"

@implementation DTUSBMonitor

@synthesize delegate;
@synthesize devices;

static void DTUSBMonitorDeviceNotification(void *refCon, io_service_t service, natural_t messageType, void *messageArgument)
{
	DTUSBDevice	*  device = (DTUSBDevice *) refCon;

	if (messageType == kIOMessageServiceIsTerminated)
	{
		if(device)
		{
			// remove the device. it will be unsafe to access device after this call
			[device.monitor performSelectorOnMainThread:@selector(usbDeviceRemoved:) withObject:device waitUntilDone:NO];
		}
	}
}

static void DTUSBMonitorDeviceAdded(void *refCon, io_iterator_t iterator)
{
	kern_return_t       kr;
	io_service_t        usbDevice;
	IOCFPlugInInterface **plugInInterface = NULL;
	SInt32              score;
	HRESULT             res;
	
	DTUSBMonitor * monitor = (DTUSBMonitor *) refCon;
	
	assert(monitor);
	assert([monitor isKindOfClass:[DTUSBMonitor class]]);
	
	while((usbDevice = IOIteratorNext(iterator)))
	{
		DTUSBDevice * device = [[DTUSBDevice alloc] init];

		io_name_t     deviceName;
		CFStringRef   deviceNameAsCFString;	
		UInt32        locationID;
		
		uint64_t      registryId = 0LL;
		
		kr = IORegistryEntryGetRegistryEntryID(usbDevice, &registryId);
		if (KERN_SUCCESS != kr) {
			registryId = 0LL;
		}
		device->registryId = registryId;

		// Get the USB device's name.
		kr = IORegistryEntryGetName(usbDevice, deviceName);
		if (KERN_SUCCESS != kr) {
			deviceName[0] = '\0';
		}
		deviceNameAsCFString = CFStringCreateWithCString(kCFAllocatorDefault,
		                                                 deviceName,
		                                                 kCFStringEncodingASCII);
		
		// Now, get the locationID of this device. In order to do this, we need to create an IOUSBDeviceInterface 
		// for our device. This will create the necessary connections between our userland application and the 
		// kernel object for the USB Device.
		kr = IOCreatePlugInInterfaceForService(usbDevice,
		                                       kIOUSBDeviceUserClientTypeID,
		                                       kIOCFPlugInInterfaceID,
		                                       &plugInInterface,
		                                       &score);

		if ((kIOReturnSuccess != kr) || (!plugInInterface))
		{
			fprintf(stderr, "IOCreatePlugInInterfaceForService returned 0x%08x.\n", kr);
			continue;
		}
		
		// ;;;; error checking here?!!!
		// Use the plugin interface to retrieve the device interface.
		res = (*plugInInterface)->QueryInterface(plugInInterface,
		                                         CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
		                                         (LPVOID*) &device->deviceInterface);

		// Now done with the plugin interface.
		(*plugInInterface)->Release(plugInInterface);
		
		if ((res) || (device->deviceInterface == NULL))
		{
			fprintf(stderr, "QueryInterface returned %d.\n", (int) res);
			continue;
		}
		
		UInt16 vendor;
		kr = (*device->deviceInterface)->GetDeviceVendor(device->deviceInterface, &vendor);
		if (KERN_SUCCESS != kr)
		{
			fprintf(stderr, "GetDeviceVendor returned 0x%08x.\n", kr);
			continue;
		}

		UInt16 product;
		kr = (*device->deviceInterface)->GetDeviceProduct(device->deviceInterface, &product);
		if (KERN_SUCCESS != kr)
		{
			fprintf(stderr, "GetDeviceProduct returned 0x%08x.\n", kr);
			continue;
		}
		
		UInt16 version;
		kr = (*device->deviceInterface)->GetDeviceReleaseNumber(device->deviceInterface, &version);
		if (KERN_SUCCESS != kr)
		{
			fprintf(stderr, "GetDeviceReleaseNumber returned 0x%08x.\n", kr);
			continue;
		}
				
		// Now that we have the IOUSBDeviceInterface, we can call the routines in IOUSBLib.h.
		// In this case, fetch the locationID. The locationID uniquely identifies the device
		// and will remain the same, even across reboots, so long as the bus topology doesn't change.
		
		kr = (*device->deviceInterface)->GetLocationID(device->deviceInterface, &locationID);
		if (KERN_SUCCESS != kr)
		{
			fprintf(stderr, "GetLocationID returned 0x%08x.\n", kr);
			continue;
		}
		
		// Get the serial number
		CFTypeRef	serialNumberRef;
		NSString * serno = @"";
		serialNumberRef = IORegistryEntryCreateCFProperty(usbDevice, CFSTR("USB Serial Number"), kCFAllocatorDefault, 0);
		if(serialNumberRef) {
			serno = [NSString stringWithString:(NSString *)serialNumberRef];
		}
		// notify the delegate
		if(serialNumberRef) {
			CFRelease(serialNumberRef);
		}

		// create a USB device container object and fill it in
		device.location = locationID;
		device.serial = serno;
		device.vendor = vendor;
		device.product = product;
		device.name = [NSString stringWithString:(NSString *)deviceNameAsCFString];
		device.monitor = monitor;
		device.version = version;

		if([monitor matchDevice:device])
		{
			// notify the monitor a device was added
			[monitor performSelectorOnMainThread:@selector(usbDeviceAdded:)
			                          withObject:device
			                       waitUntilDone:YES];
			[device release];	// now retained by the devices array only
			
			// Register for an interest notification of this device being removed. Use a reference to our
			// private data as the refCon which will be passed to the notification callback.
			kr = IOServiceAddInterestNotification(monitor->notifyPort,            // notifyPort
			                                      usbDevice,                      // service
			                                      kIOGeneralInterest,             // interestType
			                                      DTUSBMonitorDeviceNotification, // callback
			                                      device,                         // refCon
			                                      &(device->notification));       // notification

			if (KERN_SUCCESS != kr)
			{
				printf("IOServiceAddInterestNotification returned 0x%08x.\n", kr);
			}
		}

		// Don't leave the device interface open
		kern_return_t kr = (*device->deviceInterface)->Release(device->deviceInterface);
		if (KERN_SUCCESS != kr) {
			NSLog(@"failure");
		}
		device->deviceInterface = nil;
		
		// Done with this USB device; release the reference added by IOIteratorNext
		kr = IOObjectRelease(usbDevice);
	}
}

-(BOOL)matchDevice:(DTUSBDevice *)device
{
	BOOL match = YES;
	if(vendorFilter && device.vendor != vendorFilter) match = NO;
	if(productFilter && device.product != productFilter) match = NO;
	return match;
}

-(void)usbDeviceRemoved:(DTUSBDevice *)device
{
	[devices removeObject:device];
	
	// forward to our delegate
	if(delegate == nil) return;
	if([delegate respondsToSelector:@selector(usbDeviceRemoved:)])
	{
		[delegate performSelectorOnMainThread:@selector(usbDeviceRemoved:) withObject:device waitUntilDone:NO];
	}
}

-(void)usbDeviceAdded:(DTUSBDevice *)device
{
	[devices addObject:device];
	
	// forward to our delegate
	if(delegate == nil) return;
	if([delegate respondsToSelector:@selector(usbDeviceAdded:)])
	{
		[delegate performSelectorOnMainThread:@selector(usbDeviceAdded:) withObject:device waitUntilDone:NO];
	}
}

-(id)init
{
	return [self initWithVendor:0 product:0 delegate:nil];
}

-(id)initWithVendor:(NSUInteger)theVendor product:(NSUInteger)theProduct delegate:(id)theDelegate
{
	if(self = [super init])
	{
		self.devices = [NSMutableArray array];
		
		vendorFilter = theVendor;
		productFilter = theProduct;
		self.delegate = theDelegate;
		
		CFMutableDictionaryRef matchingDict;
		kern_return_t          kr;
		CFRunLoopSourceRef     runLoopSource;
		
		matchingDict = IOServiceMatching(kIOUSBDeviceClassName);  // Interested in instances of class
		                                                          // IOUSBDevice and its subclasses
		if (matchingDict == NULL) {
			fprintf(stderr, "IOServiceMatching returned NULL.\n");
			return nil;		// ;;;
		}
		
		// We filter in two places
		// If both a vendor and product have been specified, we can filter right here
		if(productFilter && vendorFilter)
		{
			// Create a CFNumber for the idVendor and set the value in the dictionary
			CFNumberRef numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorFilter);
			CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), numberRef);
			CFRelease(numberRef);
			
			// Create a CFNumber for the idProduct and set the value in the dictionary
			numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productFilter);
			CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), numberRef);
			CFRelease(numberRef);
		}
		
		// Create a notification port and add its run loop event source to our run loop
		// This is how async notifications get set up.
		notifyPort = IONotificationPortCreate(kIOMasterPortDefault);
		runLoopSource = IONotificationPortGetRunLoopSource(notifyPort);
		
		CFRunLoopRef runLoop = CFRunLoopGetCurrent();
		CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
		
		// Now set up a notification to be called when a device is first matched by I/O Kit.
		kr = IOServiceAddMatchingNotification(notifyPort,                 // notifyPort
		                                      kIOFirstMatchNotification,  // notificationType
		                                      matchingDict,               // matching
		                                      DTUSBMonitorDeviceAdded,    // callback
		                                      self,                       // refCon
		                                      &addedIterator);            // notification
		
		// Iterate once to get already-present devices and arm the notification    
		DTUSBMonitorDeviceAdded(self, addedIterator);	
	}
	return self;
}

-(void)dealloc
{
	[devices release];

	IOObjectRelease(addedIterator);
	IONotificationPortDestroy(notifyPort);
	
	[super dealloc];
}

-(NSArray *)devicesMatchingVendor:(NSUInteger)vendor product:(NSUInteger)product
{
	NSMutableArray * devs = [NSMutableArray array];
	
	for(DTUSBDevice * device in devices)
	{
		BOOL match = YES;
		if(vendor && device.vendor != vendor) match = NO;
		if(product && device.product != product) match = NO;
		if(match) [devs addObject:device];
	}
	if([devs count] == 0)
		return nil;
	else
		return devs;
}

@end
