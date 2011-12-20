//
//  KFTask.h
//  LanternLite
//
//  Created by Author on 10/14/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//
//  Handles threading and rate-limiting of notifications
//

#import <Cocoa/Cocoa.h>

@class KFTask;

@protocol KFTaskDelegate <NSObject>

-(void)taskDidBegin:(KFTask *)theTask;
-(void)taskDidUpdateProgress:(KFTask *)theTask;
-(void)taskDidFinish:(KFTask *)theTask;
	
@end

@interface KFTask : NSObject {

	NSString * taskName;
	NSString * subtaskName;
	id delegate;
	double progress;
	NSString * errorDescription;
	volatile BOOL abort;
	volatile BOOL running;
	BOOL notifiedFinish;
	
	double lastProgressUpdate;
	BOOL indefinite;
	BOOL cancelled;
}

@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL indefinite;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) volatile BOOL abort;
@property (nonatomic, assign) volatile BOOL running;
@property (nonatomic, retain) NSString * taskName;
@property (nonatomic, retain) NSString * subtaskName;
@property (nonatomic, retain) NSString * errorDescription;

-(void)notifyBeginTask;
-(void)notifyBeginSubtask:(NSString *)subtask indefinite:(BOOL)isIndefinite;
-(void)notifyProgress:(double)theProgress;		// scale of 0.0 - 1.0
-(void)notifyFinished;
-(void)notifyErrorAndAbort:(NSString *)theError;

-(void)run;		// internal

-(BOOL)start;
-(void)cancel;
-(BOOL)canStart;

@end
