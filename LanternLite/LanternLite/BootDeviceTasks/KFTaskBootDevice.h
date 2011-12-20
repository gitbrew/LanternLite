//
//  KFTaskBootDevice.h
//  LanternLite
//
//  Created by Author on 10/14/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"
#import "KFIOSDevice.h"

@interface KFTaskBootDevice : KFTask {
	
	KFIOSDevice * device;

}

@property (nonatomic, retain) KFIOSDevice * device;

@end
