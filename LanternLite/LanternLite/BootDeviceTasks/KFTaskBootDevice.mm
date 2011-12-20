//
//  KFTaskBootDevice.mm
//  LanternLite
//
//  Created by Author on 10/14/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTaskBootDevice.h"
#include "libirecovery.h"
#include "common.h"
#include "exploits.h"
#include "itunnel_main.h"

@implementation KFTaskBootDevice

@synthesize device;

-(id)init
{
	if(self = [super init])
	{
		self.taskName = @"Boot Device";
	}
	return self;
}

// Mostly broken at the moment since iOS5. Boot device using script + redsn0w for now

-(void)run
{
	// this is a snapshot of the device id before it was put into DFU mode
	// the device-to-model mapping table is in KFIOSDevice.m - make sure it's accurate
	NSString * deviceSuffix = device.hardware;
	if(deviceSuffix == nil)
	{
		NSLog(@"don't have model identifer (i.e. n88ap, etc.) for this device - look in KFIOSDevice.m");
		[self notifyErrorAndAbort:@"Device not supported"];
	}
	/*	
	// locate the firmware images from the application bundle
	// naming convention is [model].[firmware type], e.g. n88ap.kernelcache, n88ap.iBSS, n88ap.DeviceTree
	NSString * patchedKernelCache = [[NSBundle mainBundle] pathForResource:deviceSuffix ofType:@"kernelcache"];
	NSString * patchedIBSS = [[NSBundle mainBundle] pathForResource:deviceSuffix ofType:@"iBSS"];
  NSString * patchedIBEC = [[NSBundle mainBundle] pathForResource:deviceSuffix ofType:@"iBEC"];
	NSString * unpatchedDeviceTree = [[NSBundle mainBundle] pathForResource:deviceSuffix ofType:@"DeviceTree"];
	NSString * ramDisk = [[NSBundle mainBundle] pathForResource:@"myramdisk" ofType:@"dmg"];
  
	// make sure we've got the right files for this device
	NSFileManager * fm = [[[NSFileManager alloc] init] autorelease];
	if(![fm fileExistsAtPath:patchedKernelCache])
	{
		NSLog(@"missing kernel cache file %@", patchedKernelCache);
		[self notifyErrorAndAbort:@"Device not supported"];
	}
	if(![fm fileExistsAtPath:patchedIBSS])
	{
		NSLog(@"missing iBSS file %@", patchedIBSS);
		[self notifyErrorAndAbort:@"Device not supported"];
	}
	if(![fm fileExistsAtPath:unpatchedDeviceTree])
	{
		NSLog(@"missing DeviceTree file %@", unpatchedDeviceTree);
		[self notifyErrorAndAbort:@"Device not supported"];
	}
  
  // waits for device to be in DFU mode, then sends DFU exploit
  
  [self notifyBeginSubtask:@"Initializing libirecovery" indefinite:YES];
  
  irecv_init();              // initialize libirecovery
	irecv_set_debug_level(1);  // enable debugging output
	
  irecv_error_t error = IRECV_E_SUCCESS;
  
  */
  
  [self notifyBeginSubtask:@"Killing iTunes" indefinite:YES];
  
	system("killall -9 iTunesHelper");
	
  /*
	
  [self notifyBeginSubtask:@"Exploiting DFU" indefinite:YES];
  
  NSLog(@"Checking if device is in DFU mode");
  error = irecv_open(&irec_client);
	if (error != IRECV_E_SUCCESS)
	{
		[self notifyErrorAndAbort:@"Cannot connect to device"];
	}
  if (irec_client->mode != kDfuMode)
	{
    irecv_close(irec_client);
		[self notifyErrorAndAbort:@"Device is not in DFU mode\n"];
  }
	NSLog(@"Found device in DFU mode\n");
	

	NSLog(@"Checking the device type\n");
  error = irecv_get_device(irec_client, &irec_device);
	if (irec_device == NULL)
	{
    NSLog(@"Device model not recognized\n");
		[self notifyErrorAndAbort:@"Device not supported"];
	}
	NSLog(@"Identified device as %s\n", irec_device->product);
	
  
  NSLog(@"Checking if device is compatible with exploit\n");
  if (irec_device->chip_id == 8930 || irec_device->chip_id == 8920 || irec_device->chip_id == 8922)
	{
		NSLog(@"Preparing to upload limera1n exploit\n");
		if (limera1n_exploit() < 0)
		{
			NSLog(@"Unable to upload exploit data\n");
			[self notifyErrorAndAbort:@"DFU Exploitation Failed"];
		}
	}
	else if (irec_device->chip_id == 8720)
	{
    NSLog(@"Preparing to upload steaks4uce exploit\n");
		if (steaks4uce_exploit() < 0)
		{
			NSLog(@"Unable to upload exploit data\n");
			[self notifyErrorAndAbort:@"DFU Exploitation Failed"];
		}
	}
  // PWNAGE
  else if (irec_device->chip_id == 8900)
  {
    NSLog(@"Preparing to upload pwnage2 exploit\n");
    if(pwnage2_exploit() < 0)
    {
      NSLog(@"Unable to upload exploit data\n");
      [self notifyErrorAndAbort:@"DFU Exploitation Failed"];
    }
  }
  //
	else
	{
		NSLog(@"No exploit available for this device\n");
		[self notifyErrorAndAbort:@"Device not supported"];
	}
	
	[self notifyBeginSubtask:@"Uploading iBSS" indefinite:YES];
  
	NSLog(@"Preparing to upload iBSS\n");
	
  if (irec_client->mode != kDfuMode)
	{
		NSLog(@"Resetting device counters\n");
		error = irecv_reset_counters(irec_client);
		if (error != IRECV_E_SUCCESS)
		{
			NSLog(@"%@\n", irecv_strerror(error));
			[self notifyErrorAndAbort:@"Unable to upload iBSS"];
		}
	}
	NSLog(@"Uploading %@ to device\n", patchedIBSS);
	error = irecv_send_file(irec_client, [patchedIBSS fileSystemRepresentation], 1);
	if (error != IRECV_E_SUCCESS)
	{
		NSLog(@"%@\n", irecv_strerror(error));
    [self notifyErrorAndAbort:@"Unable to upload iBSS"];
	}
	NSLog(@"Reconnecting to device\n");
	irec_client = irecv_reconnect(irec_client, 10);
	if (irec_client == NULL)
	{
		[self notifyErrorAndAbort:@"Unable to reconnect to device after uploading iBSS"];
	}
  
  //
  NSLog(@"Preparing to upload iBEC\n");
  
  error = IRECV_E_SUCCESS;
  if (irec_client->mode != kDfuMode)
	{
		NSLog(@"Resetting device counters\n");
		error = irecv_reset_counters(irec_client);
		if (error != IRECV_E_SUCCESS)
		{
			NSLog(@"%@\n", irecv_strerror(error));
			[self notifyErrorAndAbort:@"Unable to upload iBEC"];
		}
	}
	NSLog(@"Uploading %@ to device\n", patchedIBEC);
	error = irecv_send_file(irec_client, [patchedIBEC fileSystemRepresentation], 1);
	if (error != IRECV_E_SUCCESS)
	{
		NSLog(@"%@\n", irecv_strerror(error));
    [self notifyErrorAndAbort:@"Unable to upload iBEC"];
	}
  NSLog(@"Reconnecting to device\n");
	irec_client = irecv_reconnect(irec_client, 10);
	if (irec_client == NULL)
	{
		[self notifyErrorAndAbort:@"Unable to reconnect to device after uploading iBEC"];
  }
  NSLog(@"Sending go command\n");
  error = irecv_send_command(irec_client, "go");
  if (error != IRECV_E_SUCCESS)
  {
    NSLog(@"%@\n", irecv_strerror(error));
    [self notifyErrorAndAbort:@"Failure sending go command"];
  }
  NSLog(@"Reconnecting to device\n");
	irec_client = irecv_reconnect(irec_client, 10);
	if (irec_client == NULL)
	{
		[self notifyErrorAndAbort:@"Unable to reconnect to device after sending go command"];
	}
  //
   
  [self notifyBeginSubtask:@"Exiting libirecovery" indefinite:YES];

	irecv_close(irec_client);
	irecv_exit();
  
	// screen should turn white at this point
	// phone is ready to accept the patched kernel and the custom ramdisk
	
  [self notifyBeginSubtask:@"Uploading firmware/ramdisk" indefinite:YES];
  
  strncpy(g_ibec, [patchedIBEC fileSystemRepresentation], BUFSIZ);
	strncpy(g_ramdisk, [ramDisk fileSystemRepresentation], BUFSIZ);
	strncpy(g_devicetree, [unpatchedDeviceTree fileSystemRepresentation], BUFSIZ);
	strncpy(g_kernelcache, [patchedKernelCache fileSystemRepresentation], BUFSIZ);
	
	g_logFunction = LogPrintf;

	LIBMD_ERROR err = libmd_platform_init();
	if (err != LIBMD_ERR_SUCCESS)
	{
		NSLog(@"LIBMD error");
		[self notifyErrorAndAbort:@"Error in LIBMD"];
	}
	
	libmd_set_recovery_callback(recovery_callback, NULL);
	
	while(g_icmdState != ICMD_SENT_KERNELCACHE)
	{
		sleep(1);
	}
	
	NSLog(@"finished sending firmware/ramdisk");

	[self notifyBeginSubtask:@"Waiting 45s for device to boot" indefinite:YES];
	sleep(45);
	
	NSLog(@"the device should be finished booting now");
  */
}
   
@end
