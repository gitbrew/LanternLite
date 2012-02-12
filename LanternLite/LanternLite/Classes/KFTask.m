//
//  KFTask.m
//  LanternLite
//
//  Created by Author on 10/14/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTask.h"

@implementation KFTask

@synthesize taskName;
@synthesize subtaskName;
@synthesize delegate;
@synthesize errorDescription;
@synthesize indefinite;
@synthesize progress;
@synthesize abort;
@synthesize running;
@synthesize cancelled;

-(void)dealloc
{
	NSLog(@"freeing task %@", self.taskName);
	
	self.taskName = nil;
	self.subtaskName = nil;
	self.errorDescription = nil;
	self.delegate = nil;

	[super dealloc];
}

-(void)run
{
	assert(0);
}

-(void)runTask
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
	NSLog(@"running task %@", self.taskName);
	
	[self notifyBeginTask];
	[self run];
	[self notifyFinished];
	
	self.running = NO;

	[pool drain];
}

-(BOOL)canStart
{
	// subclass to check arguments before we get started
	return YES;
}

-(BOOL)start
{
	// check arguments
	if([self canStart] == NO) return NO;
	
	NSLog(@"starting task %@", self.taskName);

	self.running = YES;
	[NSThread detachNewThreadSelector:@selector(runTask) toTarget:self withObject:nil];
	
	return YES;
}

-(void)cancel
{
	NSLog(@"stopping task %@", self.taskName);
	[self notifyBeginSubtask:@"Cancelling..." indefinite:YES];
	self.cancelled = YES;
	self.abort = YES;
}

-(void)notifyErrorAndAbort:(NSString *)theError
{
	NSLog(@"error with task %@: %@", self.taskName, theError);

	self.errorDescription = theError;
	self.abort = YES;
	
	if(!notifiedFinish)
	{
		if(delegate && [delegate respondsToSelector:@selector(taskDidFinish:)])
		{
			[delegate performSelectorOnMainThread:@selector(taskDidFinish:) withObject:self waitUntilDone:NO];
		}
		notifiedFinish = YES;
	}
}

-(void)notifyBeginTask
{
	self.subtaskName = taskName;	// use as placeholder initially
	
	if(delegate && [delegate respondsToSelector:@selector(taskDidBegin:)])
	{
		[delegate performSelectorOnMainThread:@selector(taskDidBegin:) withObject:self waitUntilDone:NO];
	}	
}

-(void)notifyBeginSubtask:(NSString *)subtask indefinite:(BOOL)isIndefinite
{
	self.progress = 0;
	self.subtaskName = subtask;
	self.indefinite = isIndefinite;

	if(delegate && [delegate respondsToSelector:@selector(taskDidUpdateProgress:)])
	{
		[delegate performSelectorOnMainThread:@selector(taskDidUpdateProgress:) withObject:self waitUntilDone:NO];
	}
}

-(void)notifyProgress:(double)theProgress
{
	self.progress = theProgress;
	
	double now = [[NSDate date] timeIntervalSinceReferenceDate];
	if((now - lastProgressUpdate) >= 0.100)
	{
		if(delegate && [delegate respondsToSelector:@selector(taskDidUpdateProgress:)])
		{
			[delegate performSelectorOnMainThread:@selector(taskDidUpdateProgress:) withObject:self waitUntilDone:NO];
		}
		lastProgressUpdate = now;
	}
}

-(void)notifyFinished
{
	if(!notifiedFinish)
	{
		if(delegate && [delegate respondsToSelector:@selector(taskDidFinish:)])
		{
			[delegate performSelectorOnMainThread:@selector(taskDidFinish:) withObject:self waitUntilDone:NO];
		}
		notifiedFinish = YES;
	}	
}

@end
