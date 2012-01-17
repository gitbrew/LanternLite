//
//  KFExec.m
//  LanternLite
//
//  Created by Author on 11/3/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFExec.h"

#include <sys/pipe.h>
#include <crt_externs.h>
#include <spawn.h>
#include <signal.h>
#include <stdlib.h>

@implementation KFExec

@synthesize executablePath;
@synthesize arguments;
@synthesize stdOutHandle;
@synthesize stdErrHandle;
@synthesize stdErrData;
@synthesize stdOutData;
@synthesize running;
@synthesize openFileDescriptors;
@synthesize terminationStatus;
@synthesize completionBlock;
@synthesize stdOutBlock;
@synthesize stdErrBlock;

static NSMutableArray * s_runningTasks;
static dispatch_once_t s_tasksInited;
static dispatch_queue_t s_mutexQueue;

// register an atexit() handler to cleanup on quit/exit
// tasks register themselves when launched so they can be cleaned up by our exit handler
+(void)initialize
{
	dispatch_once(&s_tasksInited, ^{
		s_runningTasks = [[NSMutableArray alloc] init];
		s_mutexQueue = dispatch_queue_create("com.katanaforensics.mutexq", NULL);
		
		atexit_b(^{
			dispatch_sync(s_mutexQueue, ^{
				for(KFExec * task in s_runningTasks)
				{
					NSLog(@"atexit: killing task");
					[task kill];
				}
			});
		});
	});
}

+(void)registerTask:(KFExec *)theTask
{
	// lazy way to serialize access to the s_runningTasks array for threadsafety
	dispatch_sync(s_mutexQueue, ^{
		[s_runningTasks addObject:theTask];
	});
}

+(void)deregisterTask:(KFExec *)theTask
{
	// lazy way to serialize access to the s_runningTasks array for threadsafety
	dispatch_sync(s_mutexQueue, ^{
		[s_runningTasks removeObject:theTask];
	});
}

// create a new KFExec with a python script stored in the application bundle
// obtains the script's full path name, then calls /usr/bin/python -B <script-path> <args>
// create the args array using [myArgString componentsSeparatedByString:@" "] if it contains no extra spaces
-(id)initWithBundledPythonScript:(NSString *)pythonScript arguments:(NSArray *)args
{
	if(self = [super init])
	{
		NSString * pathExt = [pythonScript pathExtension];
		if([pathExt length] == 0) pathExt = @"py";
		NSString * scriptPath = [[NSBundle mainBundle] pathForResource:pythonScript ofType:pathExt inDirectory:@"PythonScripts"];
		if(scriptPath == nil)
		{
			NSLog(@"error: script %@ not found", pythonScript);
		}
		else
		{
			self.executablePath = @"python";

			// Build the arguments list
			// First arg is -B (don't want to write .pyc files into app directory), then the script, and the rest are the supplied arguments
			NSMutableArray * taskArgs = [[NSMutableArray new] autorelease];
			[taskArgs addObject:@"-B"];
			[taskArgs addObject:scriptPath];
			if(args) [taskArgs addObjectsFromArray:args];
			self.arguments = taskArgs;
		}
	}
	return self;
}

// initialize with array
// create the args array using [myArgString componentsSeparatedByString:@" "] if it contains no extra spaces
// object at args[0] is executable path (must be full path), any subsequent objects are arguments passed to it
-(id)initWithArgs:(NSArray *)args
{
	if(self = [super init])
	{
		NSMutableArray * mutableArgs = [NSMutableArray arrayWithArray:args];
		
		self.executablePath = [mutableArgs objectAtIndex:0];
		[mutableArgs removeObjectAtIndex:0];
		self.arguments = mutableArgs;
	}
	return self;
}

// start the task, returning YES if successfully launched
// just let the task run until completion, with no notification that it finished
-(BOOL)launch
{
	return [self launchWithCompletionBlock:nil];
}

// start the task, and execute the provided block when the task is finished
// use this if you want to do something with stdOut, stdErr, etc.
-(BOOL)launchWithCompletionBlock:(KFExecCompletionBlock)aCompletionBlock
{
	// has a path been set?
	if(executablePath == nil) return NO;
	
	[self retain];		// keep us around
	
	self.completionBlock = aCompletionBlock;
		
	posix_spawn_file_actions_t fileActions;
	
	posix_spawn_file_actions_init(&fileActions);
	
	int stdoutRead = -1;
	int stdoutWrite = -1;
	int stderrRead = -1;
	int stderrWrite = -1;
	
	int pipeFD[2];
	if(pipe(pipeFD) != 0)
	{
		NSLog(@"couldn't allocate pipes");
		return NO;
	}
	stdoutRead = pipeFD[0];
	stdoutWrite = pipeFD[1];	
	fcntl(stdoutRead, F_SETFD, FD_CLOEXEC);  // Set close-on-exec

	if(pipe(pipeFD) != 0)
	{
		NSLog(@"couldn't allocate pipes");
		return NO;
	}
	stderrRead = pipeFD[0];
	stderrWrite = pipeFD[1];	
	fcntl(stderrRead, F_SETFD, FD_CLOEXEC);  // Set close-on-exec
	
	posix_spawn_file_actions_addopen(&fileActions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
	
	posix_spawn_file_actions_adddup2(&fileActions, stdoutWrite, STDOUT_FILENO);
	posix_spawn_file_actions_adddup2(&fileActions, stderrWrite, STDERR_FILENO);

	int argcount = 0;
	char * cargs[[arguments count]+2];
	
	cargs[argcount++] = (char *) [executablePath fileSystemRepresentation];
	for(NSString * arg in arguments)
	{
		cargs[argcount++] = (char *) [arg UTF8String];
	}
	cargs[argcount] = nil;
	
	// attempt to spawn the process
	int spawned = posix_spawnp(&childpid, [executablePath fileSystemRepresentation], &fileActions, NULL, cargs, *_NSGetEnviron());
	
	// cleanup before we check the result code
	posix_spawn_file_actions_destroy(&fileActions);
	
	// now check to see if the spawn was successful
	if(spawned != 0)
	{
		close(stdoutWrite);
		close(stderrWrite);
		close(stdoutRead);
		close(stderrRead);

		NSLog(@"posix_spawnp failed: %d", errno);
		return NO;
	}
	
	// we have successfully launched
	[KFExec registerTask:self];
	
	// close the child ends of the pipes
	close(stdoutWrite);
	close(stderrWrite);
	
	// set up file handle
	self.stdOutHandle = [[[NSFileHandle alloc] initWithFileDescriptor:stdoutRead closeOnDealloc:YES] autorelease];
	self.stdErrHandle = [[[NSFileHandle alloc] initWithFileDescriptor:stderrRead closeOnDealloc:YES] autorelease];
	openFileDescriptors = 2;
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
	                                         selector:@selector(taskSentData:) 
	                                             name:NSFileHandleReadCompletionNotification 
	                                           object:stdOutHandle];	
	[[NSNotificationCenter defaultCenter] addObserver:self 
	                                         selector:@selector(taskSentData:) 
	                                             name:NSFileHandleReadCompletionNotification 
	                                           object:stdErrHandle];
	
	if(stdOutBlock == nil)
		self.stdOutData = [NSMutableData data];
	
	if(stdErrBlock == nil)
		self.stdErrData = [NSMutableData data];
	
	self.running = YES;
	
	[stdOutHandle readInBackgroundAndNotify];
	[stdErrHandle readInBackgroundAndNotify];
		
	return YES;
}

// blocks the calling thread until the task is complete
// (i believe) this must be called on the same thread the task was created on
-(void)waitForCompletion
{
	while(self.running)
	{
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		[pool drain];
	}
}

-(void)kill
{
	if(self.running)
	{
		// send the kill signal
		int rc = kill(childpid, SIGKILL);
		NSLog(@"kill: %d", rc);
	}
}

-(void)dealloc
{
	NSLog(@"KFExec: dealloc");
	
	if(stdErrHandle || stdOutHandle)
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.stdErrHandle = nil;
	self.stdOutHandle = nil;
	self.stdOutData = nil;
	self.stdErrData = nil;
	self.executablePath = nil;
	self.arguments = nil;
	self.completionBlock = nil;
	self.stdOutBlock = nil;
	self.stdErrBlock = nil;
		
	[super dealloc];
}

-(void)finished
{	
	// deregister ourselves from the exit handler
	[KFExec deregisterTask:self];
	
	// cleanup and check the termination code of the process
	int termStatus = 0;
	int rc = waitpid(childpid, &termStatus, 0);
	if(rc == childpid)
	{
		self.terminationStatus = termStatus;
	}
	else
	{
		NSLog(@"waitpid failed");
	}
	
	[self release];		// decrement our "extra" reference count
	
	// finished running
	self.running = NO;
	NSLog(@"KFExec: task exited with status %d", terminationStatus);
	
	// call the completion block
	if(completionBlock) completionBlock();
	self.completionBlock = nil;
}

-(void)taskSentData:(NSNotification *)note
{		
	NSFileHandle * file = [note object];
	NSData * data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	if([data length])
	{
		if(file == stdErrHandle)
		{
			if(stdErrData) [self.stdErrData appendData:data];
			if(stdErrBlock) stdErrBlock(data);
		}
		else if(file == stdOutHandle)
		{
			if(stdOutData) [self.stdOutData appendData:data];
			if(stdOutBlock) stdOutBlock(data);
		}
		
		// enqueue the next read
		[file readInBackgroundAndNotify];  		
	}
	else
	{
		[file closeFile];
		openFileDescriptors--;
		
		if(openFileDescriptors <= 0)
		{
			[self finished];
		}
	}
}

@end
