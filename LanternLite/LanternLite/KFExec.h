//
//  KFExec.h
//  LanternLite
//
//  Created by Author on 11/3/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^KFExecCompletionBlock)(void);
typedef void (^KFExecIOBlock)(NSData * data);

@interface KFExec : NSObject {
	
	NSString * executablePath;
	NSMutableArray * arguments;
	NSFileHandle * stdOutHandle;
	NSFileHandle * stdErrHandle;
	NSMutableData * stdOutData;
	NSMutableData * stdErrData;
	BOOL running;
	int terminationStatus;
	int openFileDescriptors;

	KFExecIOBlock stdOutBlock;
	KFExecIOBlock stdErrBlock;
	KFExecCompletionBlock completionBlock;

	pid_t childpid;
}

@property (nonatomic, retain) NSString * executablePath;
@property (nonatomic, retain) NSMutableArray * arguments;
@property (nonatomic, retain) NSFileHandle * stdOutHandle;
@property (nonatomic, retain) NSFileHandle * stdErrHandle;
@property (nonatomic, retain) NSMutableData * stdOutData;
@property (nonatomic, retain) NSMutableData * stdErrData;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) int openFileDescriptors;
@property (nonatomic, assign) int terminationStatus;
@property (nonatomic, copy) KFExecCompletionBlock completionBlock;
@property (nonatomic, copy) KFExecIOBlock stdOutBlock;
@property (nonatomic, copy) KFExecIOBlock stdErrBlock;

-(id)initWithBundledPythonScript:(NSString *)pythonScript arguments:(NSArray *)args;
-(id)initWithArgs:(NSArray *)args;

-(BOOL)launch;
-(BOOL)launchWithCompletionBlock:(KFExecCompletionBlock)aCompletionBlock;

-(void)waitForCompletion;
-(void)waitForTime:(NSUInteger)seconds;
-(void)kill;

@end
