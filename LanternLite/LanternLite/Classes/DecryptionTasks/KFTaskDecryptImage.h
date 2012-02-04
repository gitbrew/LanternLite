//
//  KFTaskDecrypter.h
//  LanternLite
//
//  Created by Author on 10/21/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"
#import "KFExec.h"

@interface KFTaskDecryptImage : KFTask {

	NSURL * imageFile;
	NSURL * keyFile;
	NSURL * outFile;
	NSURL * logDir;

	NSFileHandle * decryptLogWriteHandle;
	NSFileHandle * decryptErrLogWriteHandle;

	KFExec * emfDecrypterExec;
}

@property (nonatomic, retain) NSURL * imageFile;
@property (nonatomic, retain) NSURL * keyFile;
@property (nonatomic, retain) NSURL * outFile;
@property (nonatomic, retain) NSURL * logDir;

@end
