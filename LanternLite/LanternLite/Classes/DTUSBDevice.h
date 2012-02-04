//
//  DTUSBDevice.h
//
//  Created by Author on 7/03/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

@interface DTUSBDevice : NSObject {
	
	NSUInteger vendor;
	NSUInteger product;
	NSUInteger location;
	NSUInteger version;
	NSString * serial;
	NSString * name;
	id monitor;

@public
	io_object_t          notification;
	IOUSBDeviceInterface **deviceInterface;
	uint64_t             registryId;
}

@property (nonatomic, assign) NSUInteger vendor;
@property (nonatomic, assign) NSUInteger product;
@property (nonatomic, assign) NSUInteger location;
@property (nonatomic, assign) NSUInteger version;
@property (nonatomic, assign) id monitor;
@property (nonatomic, retain) NSString * serial;
@property (nonatomic, retain) NSString * name;

@end
