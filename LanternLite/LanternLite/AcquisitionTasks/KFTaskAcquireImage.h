//
//  KFTaskAcquireImage.h
//  LanternLite
//
//  Created by Author on 9/29/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"
#import "KFExec.h"

@interface KFTaskAcquireImage : KFTask {
	
	NSURL * imageFile;		// if nil, will not retrieve the disk image	
	NSFileHandle * acquisitionLog;
	
	NSFileHandle * readHandle;
	NSFileHandle * writeHandle;
	BOOL finished;
	
	long long expectedSize;
	long long receivedSize;
	
	KFExec * sha1HashExec;
	NSUInteger sha1HashExecStatus;
	NSMutableData * stdOutData;
}

@property (nonatomic, retain) NSURL * imageFile;
@property (nonatomic, retain) NSFileHandle * acquisitionLog;

@end
