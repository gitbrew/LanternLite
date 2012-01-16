//
//  KFIOSDevice.m
//  LanternLite
//
//  Created by Author on 9/26/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFIOSDevice.h"

@implementation KFIOSDevice

@synthesize usbDevice;
@synthesize usbLocation;
@synthesize dfuInfo;
@synthesize model;
@synthesize modelID;
@synthesize name;
@synthesize cpid;
@synthesize bdid;
@synthesize udid;
@synthesize imageable;


+(BOOL)checkDFUModeDevice:(DTUSBDevice *)theDevice
{
	if(theDevice.vendor == APPLE_USB_ID && theDevice.product == DFU2_ID)
	{
		return YES;
	}
	return NO;
}

-(NSDictionary *)parseDFUSerial:(NSString *)vstring
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

-(void)identifyIOSDevice
{
	self.dfuInfo = [self parseDFUSerial:self.usbDevice.serial];
	if(self.dfuInfo)
	{
		self.cpid = [self.dfuInfo valueForKey:@"CPID"];
		self.bdid = [self.dfuInfo valueForKey:@"BDID"];
		NSLog(@"%@", self.dfuInfo);
	}

	NSString * path = [[NSBundle mainBundle] pathForResource:@"idevices" ofType:@"plist"];
	NSArray * knownDevices = [NSArray arrayWithContentsOfFile:path];
	for(NSDictionary * entry in knownDevices)
	{
		NSString * cpidField = [entry valueForKey:@"cpid"];
		NSString * bdidField = [entry valueForKey:@"bdid"];
		
		if([cpidField isEqualToString:self.cpid] && [bdidField isEqualToString:self.bdid])
		{
			self.model      =  [entry valueForKey:@"model"];
			self.modelID    =  [entry valueForKey:@"modelID"];
			self.name       =  [entry valueForKey:@"name"];
			self.imageable  = [[entry valueForKey:@"imageable"] boolValue];
			break;
		}
	}
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@: model %@ modelID %@ location 0x%08x",
					name, model, modelID, usbLocation];
}

@end

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
