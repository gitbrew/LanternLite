//
//  DTUSBDevice.m
//
//  Created by Author on 7/03/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "DTUSBDevice.h"

@implementation DTUSBDevice

@synthesize vendor;
@synthesize product;
@synthesize serial;
@synthesize name;
@synthesize location;
@synthesize version;
@synthesize monitor;

-(NSString *)description
{
	if([serial length])
		return [NSString stringWithFormat:@"%@: %d,%d @ 0x%08x sn %@", name, vendor, product, location, serial];
	else
		return [NSString stringWithFormat:@"%@: %d,%d @ 0x%08x", name, vendor, product, location];
}

-(void)dealloc
{
	if(deviceInterface)
	{
		kern_return_t kr = (*deviceInterface)->Release(deviceInterface);
		if(kr != KERN_SUCCESS) {
			NSLog(@"failure");
		}
		deviceInterface = nil;
	}
	
	if(notification)
	{
		kern_return_t kr = IOObjectRelease(notification);
		if(kr != KERN_SUCCESS) {
			NSLog(@"failure");
		}
		notification = 0;
	}
	
	[serial release];
	[name release];
	[super dealloc];
}

@end
