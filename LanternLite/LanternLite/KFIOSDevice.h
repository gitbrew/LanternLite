//
//  KFIOSDevice.h
//  LanternLite
//
//  Created by Author on 9/26/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "DTUSBDevice.h"

#define MODE_NORMAL		1
#define MODE_DFU		3
#define MODE_RECOVERY	2
#define MODE_INVALID	0

@interface KFIOSDevice : NSObject {
	
	NSDictionary * dfuInfo;
	NSString * model;
	NSString * udid;
	NSString * name;
	DTUSBDevice * usbDevice;
	unsigned long usbLocation;
	NSUInteger mode;
	BOOL attached;
	BOOL identified;
	BOOL imageable;
}

@property (nonatomic, retain) NSDictionary * dfuInfo;
@property (nonatomic, retain) NSString * model;
@property (nonatomic, retain) NSString * udid;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) DTUSBDevice * usbDevice;
@property (nonatomic, assign) unsigned long usbLocation;
@property (nonatomic, assign) NSUInteger mode;
@property (nonatomic, assign) BOOL attached;
@property (nonatomic, assign) BOOL identified;
@property (nonatomic, assign) BOOL imageable;
@property (readonly) NSString * hardware;

@end
