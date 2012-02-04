//
//  KFIOSDevice.h
//  LanternLite
//
//  Created by Author on 9/26/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "DTUSBDevice.h"

#define APPLE_USB_ID  1452
#define DFU1_ID       4642
#define DFU2_ID       4647
#define RECOVERY1_ID  4736
#define RECOVERY2_ID  4737
#define RECOVERY3_ID  4738
#define RECOVERY4_ID  4739

@interface KFIOSDevice : NSObject {
	
	DTUSBDevice * usbDevice;
	unsigned long usbLocation;

	NSDictionary * dfuInfo;
	
	NSString * model;
	NSString * modelID;
	NSString * name;
	NSString * cpid;
	NSString * bdid;
	NSString * udid;
	BOOL imageable;
}

@property (nonatomic, retain) DTUSBDevice * usbDevice;
@property (nonatomic, assign) unsigned long usbLocation;
@property (nonatomic, retain) NSDictionary * dfuInfo;
@property (nonatomic, retain) NSString * model;
@property (nonatomic, retain) NSString * modelID;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * cpid;
@property (nonatomic, retain) NSString * bdid;
@property (nonatomic, retain) NSString * udid;
@property (nonatomic, assign) BOOL imageable;

+(BOOL)checkDFUModeDevice:(DTUSBDevice *)theDevice;
-(void)identifyIOSDevice;

@end
