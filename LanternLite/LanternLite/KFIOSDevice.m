//
//  KFIOSDevice.m
//  LanternLite
//
//  Created by Author on 9/26/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFIOSDevice.h"

@implementation KFIOSDevice

@synthesize dfuInfo;
@synthesize model;
@synthesize udid;
@synthesize name;
@synthesize usbDevice;
@synthesize usbLocation;
@synthesize mode;
@synthesize attached;
@synthesize identified;
@synthesize imageable;


-(NSString *)hardware
{
	NSString * hw = nil;
	if([model isEqualToString:@"iPhone1,1"]) hw = @"m68ap";
	if([model isEqualToString:@"iPhone1,2"]) hw = @"n82ap";
	if([model isEqualToString:@"iPhone2,1"]) hw = @"n88ap";
	if([model isEqualToString:@"iPhone3,1"]) hw = @"n90ap";
	if([model isEqualToString:@"iPhone3,3"]) hw = @"n92ap";
	if([model isEqualToString:@"iPad1,1"]) hw = @"k48ap";
	if([model isEqualToString:@"iPod3,1"]) hw = @"n18ap";
	if([model isEqualToString:@"iPod4,1"]) hw = @"n81ap";
	return hw;
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@: model %@ location 0x%08x ident %d mode %d attach %d",
			name, model, usbLocation, identified, mode, attached];
}

@end
