//
//  KFTaskAcquireImage.h
//  LanternLite
//
//  Created by Author on 9/29/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"

@interface KFTaskAcquireImage : KFTask {
	
	NSURL * imageFile;		// if nil, will not retrieve the disk image	
	
	NSFileHandle * readHandle;
	NSFileHandle * writeHandle;
	BOOL finished;
	
	long long expectedSize;
	long long receivedSize;
}

@property (nonatomic, retain) NSURL * imageFile;

@end
