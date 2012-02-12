//
//  KFTaskBootDevice.m
//  LanternLite
//
//  Created by Author on 10/14/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTaskBootDevice.h"

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

// Mostly broken at the moment since iOS5. Boot device using redsn0w for now

-(void)run
{	
	// make sure we have redsn0w and ipsw on the desktop (probably better to do this with canStart)
	NSURL * desktopPath = [NSURL fileURLWithPath:[@"~/Desktop" stringByExpandingTildeInPath]];
	NSURL * patchedFilesPath = [NSURL fileURLWithPath:[@"~/Library/Application Support/LanternLite/patched" stringByExpandingTildeInPath]];
	NSString * ipswName = [NSString stringWithFormat:@"%@_5.0_9A334_Restore.ipsw", device.model];
	
	NSFileManager * fm = [[[NSFileManager alloc] init] autorelease];
	if(![fm fileExistsAtPath:[[desktopPath URLByAppendingPathComponent:@"redsn0w.app"] path]])
	{
		NSLog(@"missing %@", [desktopPath URLByAppendingPathComponent:@"redsn0w.app"]);
		[self notifyErrorAndAbort:@"redsn0w not found"];
		return;
	}
	if(![fm fileExistsAtPath:[[desktopPath URLByAppendingPathComponent:ipswName] path]])
	{
		NSLog(@"missing %@", [desktopPath URLByAppendingPathComponent:ipswName]);
		[self notifyErrorAndAbort:@"IPSW not found"];
		return;
	} 
	
	// get paths to components of redsn0w bundle
	NSMutableArray * rsAppPathComponents = [NSMutableArray array];
	[rsAppPathComponents addObject:[desktopPath path]];
	[rsAppPathComponents addObject:@"redsn0w.app"];
	[rsAppPathComponents addObject:@"Contents/MacOS/redsn0w"];
	NSURL * rsAppPath = [NSURL fileURLWithPathComponents:rsAppPathComponents];
	
	NSMutableArray * rsPlistPathComponents = [NSMutableArray array];
	[rsPlistPathComponents addObject:[desktopPath path]];
	[rsPlistPathComponents addObject:@"redsn0w.app"];
	[rsPlistPathComponents addObject:@"Contents/MacOS/Keys.plist"];
	NSURL * rsPlistPath = [NSURL fileURLWithPathComponents:rsPlistPathComponents];
	
	// borrow Keys.plist from redsn0w - needed for upcoming kernel/ramdisk patching
	NSLog(@"Copying Keys.plist");
	[fm createDirectoryAtPath:[patchedFilesPath path] withIntermediateDirectories:YES attributes:nil error:nil];
	if([fm isReadableFileAtPath:[rsPlistPath path]])
	{
		[fm copyItemAtURL:rsPlistPath toURL:[patchedFilesPath URLByAppendingPathComponent:@"Keys.plist"] error:nil];
	}
	else
	{
		[self notifyErrorAndAbort:@"Unable to read Keys.plist"];
		return;
	}
	
	// extract and patch kernelcache and restore ramdisk
	[self notifyBeginSubtask:@"Patching files from IPSW" indefinite:YES];
	
	// start by running kernel_patcher.py and capturing its output for the next stage
	NSLog(@"Patching kernel");
	NSMutableArray * kernelPacherArgs = [NSMutableArray array];
	[kernelPacherArgs addObject:[NSString stringWithFormat:@"%@/%@", [desktopPath path], ipswName]]; //arg1: path to ipsw
	[kernelPacherArgs addObject:device.modelID];                                                     //arg2: model hw ID string
	[kernelPacherArgs addObject:[patchedFilesPath path]];                                            //arg3: path to patched dir
	
	kernelPatcherExec = [[KFExec alloc] initWithBundledPythonScript:@"kernel_patcher" arguments:kernelPacherArgs];
	kernelPatcherStdOut = [NSMutableData data];
	kernelPatcherExec.stdOutBlock = ^(NSData * data) {
		[kernelPatcherStdOut appendData:data];
	};
	[kernelPatcherExec launchWithCompletionBlock:^(void) {
		NSLog(@"%@ exited with %d", kernelPatcherExec.executablePath, kernelPatcherExec.terminationStatus);
	}];
	
	[kernelPatcherExec waitForCompletion];
	
	NSString * kernelPatcherStdOutStr = [[[NSString alloc] initWithData:kernelPatcherStdOut encoding:NSUTF8StringEncoding] autorelease];
	NSLog(@"%@", kernelPatcherStdOutStr);
	NSArray * ramdiskInfos = [kernelPatcherStdOutStr componentsSeparatedByString:@" "];
	
	// kernel_patcher.py returns "OK" as first value if successful
	NSString * kernelPatcherStatus = [ramdiskInfos objectAtIndex:0];
	if(![kernelPatcherStatus isEqualToString:@"OK"])
	{
		[self notifyErrorAndAbort:@"Kernel patching failed"];
		return;
	}
	
	// ramdiskInfos[1]: filename of restore ramdisk
	// ramdiskInfos[2]: file key
	// ramdiskInfos[3]: file iv
	NSLog(@"Building ramdisk");
	NSMutableArray * ramdiskBuilderArgs = [NSMutableArray array];
	[ramdiskBuilderArgs addObject:[[NSBundle mainBundle] pathForResource:@"build_ramdisk" ofType:@"sh"]];
	[ramdiskBuilderArgs addObject:[[NSBundle mainBundle] resourcePath]];
	[ramdiskBuilderArgs addObject:[NSString stringWithFormat:@"%@/%@", [desktopPath path], ipswName]];
	[ramdiskBuilderArgs addObject:[patchedFilesPath path]];
	[ramdiskBuilderArgs addObject:device.modelID];
	[ramdiskBuilderArgs addObject:[ramdiskInfos objectAtIndex:1]];
	[ramdiskBuilderArgs addObject:[ramdiskInfos objectAtIndex:2]];
	[ramdiskBuilderArgs addObject:[ramdiskInfos objectAtIndex:3]];
	
	ramdiskBuilderExec = [[KFExec alloc] initWithArgs:ramdiskBuilderArgs];
	ramdiskBuilderStdOut = [NSMutableData data];
	ramdiskBuilderStdErr = [NSMutableData data];
	ramdiskBuilderExec.stdOutBlock = ^(NSData * data) {
		[ramdiskBuilderStdOut appendData:data];
	};
	ramdiskBuilderExec.stdErrBlock = ^(NSData * data) {
		[ramdiskBuilderStdErr appendData:data];
	};
	[ramdiskBuilderExec launch];
	[ramdiskBuilderExec waitForCompletion];
	
	NSLog(@"build_ramdisk complete");
	NSLog(@"stdout: %@", ramdiskBuilderStdOut);
	NSLog(@"stderr: %@", ramdiskBuilderStdErr);
	
	
	[self notifyBeginSubtask:@"Killing iTunes" indefinite:YES];
  system("killall -9 iTunesHelper");
	
	[self notifyBeginSubtask:@"Launching redsn0w" indefinite:YES];
	
	NSMutableArray * redsn0wArgs = [NSMutableArray array];
	[redsn0wArgs addObject:[rsAppPath path]];
	[redsn0wArgs addObject:@"-i"];
	[redsn0wArgs addObject:[NSString stringWithFormat:@"%@/%@", [desktopPath path], ipswName]];
	[redsn0wArgs addObject:@"-r"];
	[redsn0wArgs addObject:[NSString stringWithFormat:@"%@/%@.myramdisk.dmg", [patchedFilesPath path], device.modelID]];
	[redsn0wArgs addObject:@"-k"];
	[redsn0wArgs addObject:[NSString stringWithFormat:@"%@/%@.kernelcache", [patchedFilesPath path], device.modelID]];
	
	redsn0wExec = [[KFExec alloc] initWithArgs:redsn0wArgs];
	[redsn0wExec launch];
	
	// hack: should send notification from ramdisk once ready so there is no guesswork
	// completes when redsn0w exits (killed automatically after 1m)
	[self notifyBeginSubtask:@"Waiting 1 mintue for redsn0w to complete" indefinite:YES];
	[redsn0wExec waitForTime:60];
  [redsn0wExec kill];
	
	// wait a little more
	[self notifyBeginSubtask:@"Waiting 45s for device to boot" indefinite:YES];
	sleep(45);
	
	NSLog(@"the device should be finished booting now");
}
   
@end
