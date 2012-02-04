//
//  KFTaskBootDevice.h
//  LanternLite
//
//  Created by Author on 10/14/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"
#import "KFExec.h"
#import "KFIOSDevice.h"

@interface KFTaskBootDevice : KFTask {
	
	KFIOSDevice * device;
	
	KFExec * redsn0wExec;
	KFExec * kernelPatcherExec;
	KFExec * ramdiskBuilderExec;
	
	NSMutableData * kernelPatcherStdOut;
	NSMutableData * ramdiskBuilderStdOut;
	NSMutableData * ramdiskBuilderStdErr;
}

@property (nonatomic, retain) KFIOSDevice * device;

@end
