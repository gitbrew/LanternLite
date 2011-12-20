//
//  KFTaskAcquireKeys.h
//  LanternLite
//
//  Created by Author on 10/26/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"

@interface KFTaskAcquireKeys : KFTask {

	NSURL * keyFile;
	NSString * passcode;

}

@property (nonatomic, retain) NSURL * keyFile;
@property (nonatomic, retain) NSString * passcode;

@end
