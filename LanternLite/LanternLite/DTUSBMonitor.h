//
//  DTUSBMonitor.h
//
//  Created by Author on 7/03/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DTUSBDevice.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

@protocol DTUSBMonitorDelegate

-(void)usbDeviceAdded:(DTUSBDevice *)device;
-(void)usbDeviceRemoved:(DTUSBDevice *)device;

@end

@interface DTUSBMonitor : NSObject {
	
	NSMutableArray * devices;
	
	NSUInteger vendorFilter;
	NSUInteger productFilter;
	
	id delegate;
	
	IONotificationPortRef notifyPort;
	io_iterator_t         addedIterator;
}

@property(nonatomic, assign) id delegate;
@property(nonatomic, retain) NSMutableArray * devices;

-(id)initWithVendor:(NSUInteger)theVendor product:(NSUInteger)theProduct delegate:(id)theDelegate;
-(BOOL)matchDevice:(DTUSBDevice *)device;

-(NSArray *)devicesMatchingVendor:(NSUInteger)vendor product:(NSUInteger)product;

@end
