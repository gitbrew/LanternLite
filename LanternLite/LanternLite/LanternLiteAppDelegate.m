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
@synthesize device;
@synthesize taskQueue;
@synthesize acquisitionLog;
@synthesize optionBootDevice;
@synthesize optionRetrieveKeys;
@synthesize optionImageDataPartition;
@synthesize optionDecryptImage;
@synthesize ignoreUSBStateChange;
@synthesize acquisitionOptionsAccessoryView;


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
	
	[rightButton setEnabled:NO];
	[cancelButton setEnabled:NO];
	
	[[DTUSBMonitor alloc] initWithVendor:0 product:0 delegate:self];
	self.device = [[[KFIOSDevice alloc] init] autorelease];
	
	[testButton setHidden:YES];
}

# pragma mark - UI -

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
	if([KFIOSDevice checkDFUModeDevice:device.usbDevice])
	{
		ignoreUSBStateChange = YES;
	
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
						[self queueTasks:device targetDir:url];
					}
				}];
			}
			else
			{
				[self queueTasks:device targetDir:url];
			}
		}
	}		
}

// updates text in the main UI window
-(void)uiUpdateOnUSBStateChange
{
	NSMutableString * text = [NSMutableString string];
	if(!ignoreUSBStateChange)
	{
		if(!device.usbDevice)
		{
			[text appendFormat:@"Please connect a compatible iOS device to computer and enter DFU mode as follows:\n"];
			[text appendFormat:@"\n"];
			[text appendFormat:@"1) Power off the device (please wait for the device to shut down completely!)\n"];
			[text appendFormat:@"2) Hold the Power button for 3 seconds\n"];
			[text appendFormat:@"3) Keeping the Power button held down, press and hold the Home button\n"];
			[text appendFormat:@"4) Keep both buttons held for 10 seconds\n"];
			[text appendFormat:@"5) Release the Power button, still holding the Home button\n"];
			[text appendFormat:@"6) Hold for 10 seconds\n"];
			[text appendFormat:@"7) Release the home button\n"];
			[rightButton setEnabled:NO];
		}
		else if(!device.imageable)
		{
			[text appendFormat:@"The attached device (%@) is not yet supported\n", device.name];
			[rightButton setEnabled:NO];
		}
		else if([KFIOSDevice checkDFUModeDevice:device.usbDevice])
		{	
			[text appendFormat:@"DFU mode has been successfully entered\n"];
			[text appendFormat:@"\n"];
			[text appendFormat:@"After clicking next, the custom firmware will be generated and redsn0w will launch to continue the device bootup process\n"];
			[text appendFormat:@"\n"];
			[text appendFormat:@"Once redsn0w reports \"Done!\", quit redsn0w to continue\n"];
			[text appendFormat:@"\n"];
			[text appendFormat:@"Press NEXT to proceed\n"];
			[rightButton setEnabled:YES];
		}
	}
	else
	{
		[text appendFormat:@"Working\n"];
		[rightButton setEnabled:NO];
	}
	[textView setString:text];
}

- (void)uiReset
{
	// go back to the beginning?
	[progressIndicator setDoubleValue:0.0];
	[progressIndicator setHidden:YES];
	[statusField setStringValue:@""];
	[cancelButton setEnabled:NO];
	
	ignoreUSBStateChange = NO;
	
	// kill the python scripts (if they're running)
	[usbMuxTask kill];
	[tcpRelayTask kill];
	[usbMuxTask release];
	[tcpRelayTask release];
	tcpRelayTask = nil;
	usbMuxTask = nil;
	
}

# pragma mark - USB Stuff -

-(void)usbDeviceAdded:(DTUSBDevice *)theDevice
{
	// only act if we don't have a device connected at the moment
	if(!device.usbDevice)
	{	
		// if we've seen this device before
		if(device.usbLocation == theDevice.location)
		{
			device.usbDevice = theDevice;
			NSLog(@"Device reconnected: %@", device);
		}
		// if it is new, and in DFU mode
		else if([KFIOSDevice checkDFUModeDevice:theDevice])
		{
			device.usbDevice = theDevice;
			device.usbLocation = theDevice.location;
			[device identifyIOSDevice];
		}
	}
	[self uiUpdateOnUSBStateChange];
}

-(void)usbDeviceRemoved:(DTUSBDevice *)theDevice
{
	// if we have a device, see if it is now gone
	if(device.usbDevice)
	{
		if(device.usbLocation == theDevice.location)
		{
			NSLog(@"Device disconnected: %@", device);
			device.usbDevice = nil;
		}
	}
	[self uiUpdateOnUSBStateChange];
}

#pragma mark - Task Queue Management -

// This queueing mechanism is starting to be a little convoluted...

-(void)queueTasks:(KFIOSDevice *)theDevice targetDir:(NSURL *)baseDir
{
	[rightButton setEnabled:NO];

	self.taskQueue = [NSMutableArray array];
	
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

	// Log start
	NSDate * now = [NSDate date];
	NSDateFormatter * df = [[[NSDateFormatter alloc] init] autorelease];
	[df setDateStyle:NSDateFormatterMediumStyle];
	[df setTimeStyle:NSDateFormatterFullStyle];
	NSString * dateString = [df stringFromDate:now];
	NSString * outString = [NSString stringWithFormat:@"Acquisition Started: %@\n", dateString];
	NSData * outData = [outString dataUsingEncoding:NSUTF8StringEncoding];
	
	[[NSFileManager defaultManager] createFileAtPath:[[baseDir URLByAppendingPathComponent:@"AcquisitionLog.txt"] path] contents:nil attributes:nil];
	
	NSError * error = nil;
	acquisitionLog = [NSFileHandle fileHandleForWritingToURL:[baseDir URLByAppendingPathComponent:@"AcquisitionLog.txt"] error:&error];
	if(error)
	{
		NSLog(@"couldn't open Acquisition Log");
	}
	
	[acquisitionLog writeData:outData];
	[acquisitionLog synchronizeFile];

	// Boot the device
	if(optionBootDevice)
	{
		KFTask * boot = [[[KFTaskBootDevice alloc] init] autorelease];
		((KFTaskBootDevice *) boot).device = theDevice;
		boot.delegate = self;
		[taskQueue addObject:boot];
		
		// Launch the tcprelay python script
		NSArray * tcpRelayArgs = [@"-t 22:47499 1999:1999" componentsSeparatedByString:@" "];
		tcpRelayTask = [[KFExec alloc] initWithBundledPythonScript:@"tcprelay" arguments:tcpRelayArgs];
		[tcpRelayTask launch];
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
		image.acquisitionLog = self.acquisitionLog;
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
		// Log completion
		NSDate * now = [NSDate date];
		NSDateFormatter * df = [[[NSDateFormatter alloc] init] autorelease];
		[df setDateStyle:NSDateFormatterMediumStyle];
		[df setTimeStyle:NSDateFormatterFullStyle];
		NSString * dateString = [df stringFromDate:now];
		NSString * outString = [NSString stringWithFormat:@"Acquisition Complete: %@\n", dateString];
		NSData * outData = [outString dataUsingEncoding:NSUTF8StringEncoding];
		[acquisitionLog writeData:outData];
		[acquisitionLog synchronizeFile];
		[acquisitionLog closeFile];
		acquisitionLog = nil;
		
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
		[self uiReset];
		
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

#pragma mark - Growl Support -

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
