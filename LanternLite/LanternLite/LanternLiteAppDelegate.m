//
//  LanternLiteAppDelegate.m
//  LanternLite
//
//  Created by Author on 9/19/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "LanternLiteAppDelegate.h"
#import "KFIOSDevice.h"
#import "KFTaskBootDevice.h"
#import "KFTaskAcquireKeys.h"
#import "KFTaskAcquireImage.h"
#import "KFTaskDecryptImage.h"
#import "KFExec.h"

@implementation LanternLiteAppDelegate

@synthesize acquisitionWindow;
@synthesize devices;
@synthesize taskQueue;
@synthesize optionBootDevice;
@synthesize optionRetrieveKeys;
@synthesize optionImageDataPartition;
@synthesize optionDecryptImage;
@synthesize acquisitionOptionsAccessoryView;

// for C-callback progress stuff only; hack
KFTask * s_bootTask = nil;
void setProgressTaskName(const char * taskName)
{
	if(s_bootTask)
	{
		[s_bootTask notifyBeginSubtask:[NSString stringWithUTF8String:taskName] indefinite:YES];
	}
}
//

# pragma mark USB Stuff

-(KFIOSDevice *)attachedDevice
{
	KFIOSDevice * attachedDevice = nil;

	int nAttached = 0;
	for(KFIOSDevice * device in devices)
	{
		if(device.attached) 
		{
			nAttached++;
			attachedDevice = device;
		}
	}
	
	if(nAttached == 1) return attachedDevice;
	return nil;
}

// updates text in the main UI window
-(void)updateUSBAttachedState
{
	KFIOSDevice * attachedDevice = nil;
	
	int nAttached = 0;
	for(KFIOSDevice * device in devices)
	{
		if(device.attached) 
		{
			nAttached++;
			attachedDevice = device;
		}
	}

	if(ignoreUSBStateChanges)
	{
		if(nAttached == 0)
		{
			[textView setString:@"Waiting for device"];
		}
		else if(nAttached == 1)
		{
			[textView setString:@"Working"];
		}
		else
		{
			[textView setString:@"Too many iOS devices connected; please connect only one at a time."];
		}
		return;
	}
	
	if(nAttached == 0)
	{
		[textView setString:@"No iOS devices connected\nPlease connect the device for identification."];
		[rightButton setEnabled:NO];
	}
	else if(nAttached > 1)
	{
		[textView setString:@"Too many iOS devices connected; please connect only one at a time."];
		[rightButton setEnabled:NO];
	}
	else
	{
		KFIOSDevice * device = attachedDevice;
		
		NSMutableString * text = [NSMutableString string];
		[text appendFormat:@"Device: %@ (%@) connected\n",
		 device.name, device.model];
		
		if(device.imageable)
		{	
			// REMOVED FOR TEMP iOS5
			/*
			if(device.identified && device.mode == MODE_DFU)
			{
				[text appendFormat:@"DFU mode has been successfully entered\n"];
				[text appendFormat:@"Press NEXT to proceed\n"];
				[rightButton setEnabled:YES];
			}
			else if(device.identified && device.mode == MODE_RECOVERY)
			{
				[text appendFormat:@"The attached device is in recovery mode. Try the procedure again to put the device into DFU mode.\n"];
			}
			else if(device.identified && device.mode == MODE_NORMAL)
			{
				[text appendFormat:@"This device can be imaged\n"];
				[text appendFormat:@"Keep the device connected to the same USB port, and enter DFU mode as follows.\n"];
				[text appendFormat:@"\n"];
				[text appendFormat:@"1) Begin with the device connected and powered up\n"];
				[text appendFormat:@"2) Read below and then keep your eyes on the device\n"];
				[text appendFormat:@"3) Hold the top sleep/wake button and the home button simultaneously until the device powers off\n"];
				[text appendFormat:@"4) Once screen is black, count 3 seconds\n"];
				[text appendFormat:@"5) Release the top button\n"];
				[text appendFormat:@"6) Count 7 seconds\n"];
				[text appendFormat:@"7) Release the home button\n"];
			}
			*/
			[text appendFormat:@"This device can be imaged\n"];
			[text appendFormat:@"Press NEXT to proceed\n"];
			[rightButton setEnabled:YES];
		}
		else
		{
			if(device.identified)
			{
				[text appendFormat:@"The attached device is not yet supported.\n"];
			}
			else
			{
				if(device.mode == MODE_DFU)
				{
					[text appendFormat:@"The attached device is in DFU mode but has not yet been identified. Restart the device so it may be identified first. Hold down both buttons until this shows no devices connected.\n"];
				}
				else if(device.mode == MODE_RECOVERY)
				{
					[text appendFormat:@"The attached device is in recovery mode. Restart the device so it may be identified and then placed into DFU mode.\n"];
				}
			}
		}
		
		[textView setString:text];
	}
}

-(KFIOSDevice *)iosDeviceMatchingUSB:(DTUSBDevice *)theDevice
{
	for(KFIOSDevice * device in devices)
	{
		if(device.usbLocation == theDevice.location)
		{
			return device;
		}
	}
	return nil;
}

-(void)usbDeviceRemoved:(DTUSBDevice *)theDevice
{
	KFIOSDevice * device = [self iosDeviceMatchingUSB:theDevice];
	if(device)
	{
		NSLog(@"disconnected device %@", device.name);
		device.usbDevice = nil;
		device.attached = NO;
		device.mode = MODE_INVALID;
	}
	[self updateUSBAttachedState];
}

-(NSUInteger)prodFieldToInteger:(id)obj
{
	if([obj isKindOfClass:[NSString class]])
	{
		unsigned int product = 0;
		NSString * s = [obj lowercaseString];
		if([s hasPrefix:@"0x"])
		{
			NSScanner * scanner = [NSScanner scannerWithString:[s substringFromIndex:2]];
			[scanner scanHexInt:&product];
		}
		else
		{
			product = [obj intValue];
		}
		return product;
	}
	else if([obj isKindOfClass:[NSNumber class]])
	{
		return [obj intValue];
	}
	return 0;
}

-(NSDictionary *)identifyDeviceType:(DTUSBDevice *)theDevice
{
	NSString * path = [[NSBundle mainBundle] pathForResource:@"idevices" ofType:@"plist"];
	NSArray * knownDevices = [NSArray arrayWithContentsOfFile:path];
	for(NSDictionary * entry in knownDevices)
	{
		id prodField = [entry valueForKey:@"usbProduct"];
		id vendorField = [entry valueForKey:@"usbVendor"];
		
		NSUInteger product = [self prodFieldToInteger:prodField];
		NSUInteger vendor = [self prodFieldToInteger:vendorField];
		
		if(product == theDevice.product && vendor == theDevice.vendor)
		{
			return entry;
		}
	}
	
	return nil;
}

-(NSDictionary *)parseDFUVersion:(NSString *)vstring
{
	NSMutableDictionary * dict = [NSMutableDictionary dictionary];
	
	NSCharacterSet * cset = [NSCharacterSet characterSetWithCharactersInString:@"[] "];
	NSArray * blocks = [vstring componentsSeparatedByString:@" "];
	for(NSString * block in blocks)
	{
		NSArray * els = [block componentsSeparatedByString:@":"];
		if([els count] == 2)
		{
			NSString * key = [els objectAtIndex:0];
			NSString * val = [els objectAtIndex:1];
			if(val) val = [val stringByTrimmingCharactersInSet:cset];
			if([key length] && [val length])
			{
				[dict setValue:val forKey:key];
			}
		}
	}
	return dict;
}

//NSLog(@"added: %@", device);
// DFU mode: Apple Mobile Device (DFU Mode): 1452,4647 @ 0xfd130000 sn CPID:8920 CPRV:15 CPFM:03 SCEP:03 BDID:00 ECID:000003033A056DCE SRTG:[iBoot-359.3.2]
// Apple Mobile Device (DFU Mode): 1452,4647 @ 0xfd130000 sn CPID:8920 CPRV:14 CPFM:03 SCEP:01 BDID:00 ECID:000000DBCA083DF6 SRTG:[iBoot-359.3]

// recovery mode:
// Apple Mobile Device (Recovery Mode): 1452,4737 @ 0xfd130000 sn CPID:8920 CPRV:15 CPFM:03 SCEP:03 BDID:00 ECID:000003033A056DCE IBFL:01 SRNM:[86942J7F3NQ] IMEI:[012026006240395]

// iPod touch 1G USB DFU mode
// USB DFU Device: 1452,4642 @ 0xfd130000 sn 89000000000001

// iPhone 3G in USB DFU mode
// USB DFU Device: 1452,4642 @ 0xfd130000 sn 89000000000001

// Note: iPodtouch1G,iPhone,iPhone3G all share this older iBoot/DFU mode

-(void)usbDeviceAdded:(DTUSBDevice *)theDevice
{
	KFIOSDevice * existingDevice = [self iosDeviceMatchingUSB:theDevice];		// find saved entry by USB location
	NSDictionary * deviceType = [self identifyDeviceType:theDevice];
	if(deviceType == nil)  // not an iOS device
	{
		if(existingDevice)
		{
			// port has been re-used by another device
			[devices removeObject:existingDevice];
		}
	}
	else
	{
		NSString * model = [deviceType valueForKey:@"model"];
		NSString * name = [deviceType valueForKey:@"name"];
		NSNumber * imageable = [deviceType valueForKey:@"imageable"];
		
		if([model hasPrefix:@"dfu"] && existingDevice)
		{
			existingDevice.usbDevice = theDevice;
			existingDevice.mode = MODE_DFU;
			existingDevice.attached = YES;
			
			NSDictionary * info = [self parseDFUVersion:theDevice.serial];
			if(info)
			{
				existingDevice.dfuInfo = info;
				NSLog(@"%@", info);
			}
		}
		else if([model hasPrefix:@"recovery"] && existingDevice)
		{
			existingDevice.usbDevice = theDevice;
			existingDevice.mode = MODE_RECOVERY;
			existingDevice.attached = YES;
		}
		else
		{
			if(existingDevice) [devices removeObject:existingDevice];
			
			KFIOSDevice * matchByUdid = nil;
			for(KFIOSDevice * dev in devices)
			{
				if([dev.udid isEqualToString:theDevice.serial])
				{
					matchByUdid = dev;
					break;
				}
			}
			if(matchByUdid) [devices removeObject:matchByUdid];
			
			KFIOSDevice * device = [[[KFIOSDevice alloc] init] autorelease];
			device.mode = MODE_NORMAL;
			
			if([model hasPrefix:@"dfu"])
			{
				device.mode = MODE_DFU;
			}
			else if([model hasPrefix:@"recovery"])
			{
				device.mode = MODE_RECOVERY;
			}
			else
			{
				device.identified = YES;
			}

			device.model = model;
			device.udid = theDevice.serial;
			device.name = name;
			device.imageable = [imageable boolValue];
			device.usbDevice = theDevice;
			device.usbLocation = theDevice.location;
			device.attached = YES;
			[devices addObject:device];
		}
	}
	[self updateUSBAttachedState];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{	
	// Register with the Growl framework
	if(NSClassFromString(@"GrowlApplicationBridge"))		// fail gracefully if the framework didn't load
	{
		[GrowlApplicationBridge setGrowlDelegate:self];
		NSLog(@"registered with Growl");
	}
	else
	{
		NSLog(@"the Growl framework is not available");
	}
	
	self.optionBootDevice = YES;
	self.optionRetrieveKeys = YES;
	self.optionImageDataPartition = YES;
	self.optionDecryptImage = YES;
	
	self.devices = [NSMutableArray array];
	
	[rightButton setEnabled:NO];
	[cancelButton setEnabled:NO];
	
	[[DTUSBMonitor alloc] initWithVendor:0 product:0 delegate:self];
	
	[testButton setHidden:YES];
}

# pragma mark UI

-(IBAction)testButton:(id)sender
{
	// nothing right now
}

-(IBAction)cancelButton:(id)sender
{
	if([taskQueue count])
	{
		KFTask * theTask = [taskQueue objectAtIndex:0];
		[theTask retain];
		[theTask cancel];
		[taskQueue removeAllObjects];
		[taskQueue addObject:theTask];
		[theTask release];
	}
}

-(IBAction)rightButton:(id)sender
{
	KFIOSDevice * theDevice = [self attachedDevice];
	if(theDevice)
	{
		// get the current date/time in a format we can name a directory
		NSDate * rightNow = [NSDate date];
		NSDateFormatter * dirNameFormat = [[[NSDateFormatter alloc] init] autorelease];
		[dirNameFormat setDateFormat:@"yyyy-MM-dd__HH-mm-ss"];
		NSString * dirName = [dirNameFormat stringFromDate:rightNow];
		
		NSSavePanel * panel = [NSSavePanel savePanel];
		[panel setTitle:@"Save As"];
		[panel setNameFieldStringValue:[NSString stringWithFormat:@"Acquisition__%@", dirName]];
		[panel setAccessoryView:acquisitionOptionsAccessoryView];
		
		NSInteger result = [panel runModal];
		if(result == NSOKButton)
		{
			NSURL * url = [panel URL];
			
			if([[NSFileManager defaultManager] fileExistsAtPath:[url path]])
			{
				// move existing one to the trash
				[[NSWorkspace sharedWorkspace] recycleURLs:[NSArray arrayWithObject:url] completionHandler:^(NSDictionary *newURLs, NSError *error) {
					
					if(error)
					{
						// report the error
						NSAlert *alert = [[[NSAlert alloc] init] autorelease];
						[alert addButtonWithTitle:@"OK"];
						[alert setMessageText:@"Couldn't remove existing directory"];
						[alert setInformativeText:@"The previous item could not be removed."];
						[alert setAlertStyle:NSWarningAlertStyle];
						[alert beginSheetModalForWindow:[self acquisitionWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
					}
					else
					{
						[self queueTasks:theDevice targetDir:url];
					}
				}];
			}
			else
			{
				[self queueTasks:theDevice targetDir:url];
			}
		}
	}		
}

- (void)resetUI
{
	// go back to the beginning?
	[progressIndicator setDoubleValue:0.0];
	[progressIndicator setHidden:YES];
	[statusField setStringValue:@""];
	[cancelButton setEnabled:NO];
	
	// kill the python scripts (if they're running)
	[usbMuxTask kill];
	[tcpRelayTask kill];
	[usbMuxTask release];
	[tcpRelayTask release];
	tcpRelayTask = nil;
	usbMuxTask = nil;
	
	ignoreUSBStateChanges = NO;
}

#pragma mark Task Queue Management

// This queueing mechanism is starting to be a little convoluted...

-(void)queueTasks:(KFIOSDevice *)theDevice targetDir:(NSURL *)baseDir
{
	self.taskQueue = [NSMutableArray array];
	
	ignoreUSBStateChanges = YES;

	// create the directories
	if(![[NSFileManager defaultManager] createDirectoryAtPath:[baseDir path] withIntermediateDirectories:YES attributes:nil error:nil])
	{
		NSLog(@"couldn't create target directory");
		return;
	}
	NSURL * rawFilesDirectory = [baseDir URLByAppendingPathComponent:@"Raw"];
	if(![[NSFileManager defaultManager] createDirectoryAtPath:[rawFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:nil])
	{
		NSLog(@"couldn't create target directory");
		return;
	}
	NSURL * decryptedFilesDirectory = [baseDir URLByAppendingPathComponent:@"Decrypted"];
	if(![[NSFileManager defaultManager] createDirectoryAtPath:[decryptedFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:nil])
	{
		NSLog(@"couldn't create target directory");
		return;
	}
	NSURL * logFilesDirectory = [baseDir URLByAppendingPathComponent:@"Logs"];
	if(![[NSFileManager defaultManager] createDirectoryAtPath:[logFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:nil])
	{
		NSLog(@"couldn't create target directory");
		return;
	}
		
	// set paths to some files
	NSURL * keyFile = [rawFilesDirectory URLByAppendingPathComponent:@"keys.plist"];
	NSURL * rawDataImage = [rawFilesDirectory URLByAppendingPathComponent:@"data_partition.dmg"];
	NSURL * decryptedDataImage = [decryptedFilesDirectory URLByAppendingPathComponent:@"data_partition.dmg"];

	// Boot the device
	if(optionBootDevice)
	{
		KFTask * boot = [[[KFTaskBootDevice alloc] init] autorelease];
		((KFTaskBootDevice *) boot).device = theDevice;
		boot.delegate = self;
		[taskQueue addObject:boot];
		
		// Launch the tcprelay python script
		//NSArray * tcpRelayArgs = [@"-t 22:47499 1999:1999" componentsSeparatedByString:@" "];
		//tcpRelayTask = [[KFExec alloc] initWithBundledPythonScript:@"tcprelay" arguments:tcpRelayArgs];
		//[tcpRelayTask launch];
	}
	// Get the keys.plist file
	if(optionRetrieveKeys)
	{
		KFTaskAcquireKeys * jackBauer = [[[KFTaskAcquireKeys alloc] init] autorelease];
		jackBauer.delegate = self;
		jackBauer.keyFile = keyFile;
		[taskQueue addObject:jackBauer];
	}
	// Image the data partition
	if(optionImageDataPartition)
	{
		KFTaskAcquireImage * image = [[[KFTaskAcquireImage alloc] init] autorelease];
		image.delegate = self;
		image.imageFile = rawDataImage;
		[taskQueue addObject:image];
	}
	// Decrypt the data partition image
	if(optionDecryptImage)
	{
		KFTaskDecryptImage * decryptImage = [[[KFTaskDecryptImage alloc] init] autorelease];
		decryptImage.delegate = self;
		decryptImage.imageFile = rawDataImage;
		decryptImage.keyFile = keyFile;
		decryptImage.outFile = decryptedDataImage;
		decryptImage.logDir = logFilesDirectory;
		[taskQueue addObject:decryptImage];		
	}
	
	// Get things rolling...
	[self startNextTask];	
}

-(void)startNextTask
{
	if([taskQueue count])
	{
		KFTask * nextTask = [taskQueue objectAtIndex:0];
		[nextTask start];
		[cancelButton setEnabled:YES];
	}
	else
	{
		/* Play a chime sound */
		static NSSound * s_chime = nil;
		if(s_chime == nil) s_chime = [[NSSound soundNamed:@"chime"] retain];
		if(s_chime) [s_chime play];
		
		[statusField setStringValue:@"Finished!"];
		[self performSelector:@selector(resetUI) withObject:nil afterDelay:1.0];
		
		if(NSClassFromString(@"GrowlApplicationBridge"))
		{
			[GrowlApplicationBridge
			 notifyWithTitle:@"Finished"
			 description:@"All tasks completed successfully."
			 notificationName:@"TaskFinished"
			 iconData:nil
			 priority:1
			 isSticky:NO
			 clickContext:@"OrderFront"];
		}
		[cancelButton setEnabled:NO];
	}
}

-(void)taskDidBegin:(KFTask *)theTask
{
	NSLog(@"taskDidBegin: %@", theTask);

	[progressIndicator setHidden:NO];
	[statusField setHidden:NO];

	[statusField setStringValue:theTask.subtaskName];
	[progressIndicator setDoubleValue:0.0];
	[progressIndicator setMaxValue:1.0];
	[progressIndicator setMinValue:0.0];
	[progressIndicator startAnimation:self];
}

-(void)taskDidUpdateProgress:(KFTask *)theTask
{
	if([progressIndicator isIndeterminate] != theTask.indefinite)
		[progressIndicator setIndeterminate:theTask.indefinite];
	
	if(!theTask.indefinite)
		[progressIndicator setDoubleValue:theTask.progress];
	
	[statusField setStringValue:theTask.subtaskName];
}

-(void)showPasscode:(NSString *)thePasscode
{
	if([thePasscode length])
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"Passcode Retrieved"];
		[alert setInformativeText:[NSString stringWithFormat:@"The passcode is %@", thePasscode]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert beginSheetModalForWindow:[self acquisitionWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

-(void)taskDidFinish:(KFTask *)theTask
{
	NSLog(@"taskDidFinish: %@", theTask);
	
	// See if we got the keys, if so, display the results
	if([theTask isKindOfClass:[KFTaskAcquireKeys class]])
	{
		KFTaskAcquireKeys * acquireKeysTask = (KFTaskAcquireKeys *) theTask;
		if(acquireKeysTask.passcode)
			[self showPasscode:acquireKeysTask.passcode];
	}
	
	[taskQueue removeObject:theTask];
	
	if(theTask.errorDescription || theTask.cancelled)
	{
		[taskQueue removeAllObjects];
		[self resetUI];
		
		if(!theTask.cancelled)
		{
			/* Play a chime sound */
			static NSSound * s_chime = nil;
			if(s_chime == nil) s_chime = [[NSSound soundNamed:@"chime"] retain];
			if(s_chime) [s_chime play];
			
			// report to growl
			if(NSClassFromString(@"GrowlApplicationBridge"))
			{
				[GrowlApplicationBridge
				 notifyWithTitle:@"The task could not be completed"
				 description:theTask.errorDescription
				 notificationName:@"TaskFinished"
				 iconData:nil
				 priority:1
				 isSticky:NO
				 clickContext:@"OrderFront"];
			}				
			
			// report the error
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:@"The task could not be completed"];
			[alert setInformativeText:theTask.errorDescription];
			[alert setAlertStyle:NSWarningAlertStyle];
			[alert beginSheetModalForWindow:[self acquisitionWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
	}
	else
	{
		[progressIndicator setDoubleValue:1.0];
		[self startNextTask];
	}
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
		contextInfo:(void *)contextInfo
{
}

#pragma mark Growl Support

// TODO: Needs updating to support new Growl API

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSMutableDictionary * reg = [NSMutableDictionary dictionary];
	NSMutableArray * allNotes = [NSMutableArray array];
	NSMutableArray * defaultNotes = [NSMutableArray array];
	[reg setValue:[NSNumber numberWithInt:1] forKey:@"TicketVersion"];
	[allNotes addObject:@"TaskFinished"];
	[defaultNotes addObject:@"TaskFinished"];
	[reg setValue:allNotes forKey:@"AllNotifications"];
	[reg setValue:defaultNotes forKey:@"DefaultNotifications"];
	return reg;
}

- (void)growlNotificationWasClicked:(id)clickContext
{
	if(clickContext == nil) return;
	
	if([clickContext isKindOfClass:[NSString class]])
	{
		if([clickContext isEqualToString:@"OrderFront"])
		{
			[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
		}
		else if([clickContext hasPrefix:@"file:"])
		{
			NSURL * url = [NSURL URLWithString:clickContext];
			[[NSWorkspace sharedWorkspace] openURL:url];
		}
	}
}

@end
