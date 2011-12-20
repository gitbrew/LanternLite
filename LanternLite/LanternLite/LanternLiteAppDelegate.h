//
//  LanternLiteAppDelegate.h
//  LanternLite
//
//  Created by Author on 9/19/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>
#import "DTUSBMonitor.h"
#import "KFIOSDevice.h"
#import "KFTask.h"
#import "KFExec.h"

@interface LanternLiteAppDelegate : NSObject <NSApplicationDelegate,
                                              DTUSBMonitorDelegate,
                                              KFTaskDelegate,
                                              GrowlApplicationBridgeDelegate>
{
	// App windows
	NSWindow * acquisitionWindow;

	// UI feedback
	IBOutlet NSButton * testButton;
	IBOutlet NSButton * cancelButton;
	IBOutlet NSButton * rightButton;
	IBOutlet NSTextView * textView;
	IBOutlet NSTextField * statusField;
	IBOutlet NSProgressIndicator * progressIndicator;

	// Option sub panels
	IBOutlet NSView * acquisitionOptionsAccessoryView;
	
	// Acquisition options
	BOOL optionBootDevice;
	BOOL optionRetrieveKeys;
	BOOL optionImageDataPartition;
	BOOL optionDecryptImage;

	BOOL ignoreUSBStateChanges;
	BOOL imaging;

	NSMutableArray * devices;
	NSMutableArray * taskQueue;

	KFExec * usbMuxTask;
	KFExec * tcpRelayTask;
}

@property (assign) IBOutlet NSWindow * acquisitionWindow;
@property (nonatomic, retain) NSView * acquisitionOptionsAccessoryView;
@property (assign) BOOL optionBootDevice;
@property (assign) BOOL optionRetrieveKeys;
@property (assign) BOOL optionImageDataPartition;
@property (assign) BOOL optionDecryptImage;
@property (nonatomic, retain) NSMutableArray * devices;
@property (nonatomic, retain) NSMutableArray * taskQueue;

-(IBAction)testButton:(id)sender;
-(IBAction)cancelButton:(id)sender;
-(IBAction)rightButton:(id)sender;

-(void)queueTasks:(KFIOSDevice *)theDevice targetDir:(NSURL *)baseDir;
-(void)startNextTask;

@end
