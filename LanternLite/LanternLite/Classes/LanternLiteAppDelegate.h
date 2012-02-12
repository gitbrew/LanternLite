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
	IBOutlet NSButton * optionDecryptImageButton;

	BOOL ignoreUSBStateChange;
	
	NSString * errorAlert;
	
	KFIOSDevice * device;
	NSMutableArray * taskQueue;

	KFExec * tcpRelayTask;
	
	NSFileHandle * acquisitionLog;
}

@property (assign) IBOutlet NSWindow * acquisitionWindow;
@property (nonatomic, retain) NSView * acquisitionOptionsAccessoryView;
@property (assign) BOOL optionBootDevice;
@property (assign) BOOL optionRetrieveKeys;
@property (assign) BOOL optionImageDataPartition;
@property (assign) BOOL optionDecryptImage;
@property (assign) BOOL ignoreUSBStateChange;
@property (nonatomic, retain) NSString * errorAlert;
@property (retain) KFIOSDevice * device;
@property (nonatomic, retain) NSMutableArray * taskQueue;
@property (nonatomic, retain) NSFileHandle * acquisitionLog;

-(IBAction)testButton:(id)sender;
-(IBAction)cancelButton:(id)sender;
-(IBAction)rightButton:(id)sender;
-(IBAction)optionRetrieveKeysButton:(id)sender;
-(IBAction)optionImageDataPartitionButton:(id)sender;

-(void)queueTasks:(KFIOSDevice *)theDevice targetDir:(NSURL *)baseDir;
-(void)startNextTask;

@end
