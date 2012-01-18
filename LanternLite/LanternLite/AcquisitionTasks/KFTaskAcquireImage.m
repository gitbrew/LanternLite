//
//  KFTaskAcquireImage.m
//  LanternLite
//
//  Created by Author on 9/29/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTaskAcquireImage.h"
#import "LanternLiteAppDelegate.h"

@implementation KFTaskAcquireImage

@synthesize imageFile;
@synthesize acquisitionLog;

-(id)init
{
	if(self = [super init])
	{
		self.taskName = @"Acquire Image";
	}
	return self;
}

-(void)taskSentData:(NSNotification *)note
{		
	// NSFileHandle * file = [note object];
	NSData * data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	if([data length])
	{
		// write to the output file
		receivedSize += [data length];
		[writeHandle writeData:data];
		
		if(expectedSize)
		{
			double pct = ((long double) receivedSize) / ((long double) expectedSize);
			[self notifyProgress:pct];
		}
		
		// There may be more data; reschedule a read if count != 0
		[readHandle readInBackgroundAndNotify];
	}
	else
	{
		NSLog(@"finished receiving the file");
		finished = YES;
		
		[writeHandle synchronizeFile];
		[writeHandle closeFile];
		[writeHandle release];
		writeHandle = nil;
	}
}

// copied in KFAcquireKeys... put somewhere better
-(NSData *)sshDoCommand:(NSString *)command
{
	NSTask * sshTask = [[NSTask alloc] init];
	
	// Setup the pipes on the task
	NSPipe *outputPipe = [NSPipe pipe];
	NSPipe *errorPipe = [NSPipe pipe];
	[sshTask setStandardOutput:outputPipe];
	// It's important that we set the standard input to null here. This is sometimes required in order to get SSH to use our Askpass program rather then prompt the user interactively. 
	[sshTask setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
	[sshTask setStandardError:errorPipe];
	
	
	// Get the path of our Askpass program, which we've included as part of the main application bundle
	// This just spits out "alpine"
	NSString * askPassPath = [[NSBundle mainBundle] pathForResource:@"Askpass" ofType:@""];
	
	NSDictionary *environmentDict = [[NSProcessInfo processInfo] environment];
	// This creates a dictionary of environment variables (keys) and their values (objects) to be set in the environment where the task will be run. This environment dictionary will then be accessible to our Askpass program.
	NSMutableDictionary *env = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								@"NONE", @"DISPLAY", // It's important that Display is set so that ssh will use Askpass. The actual value is not important though 
								askPassPath, @"SSH_ASKPASS",
								nil];
	
	
	// This is necessary in order to allow key based login
	if ( [environmentDict objectForKey:@"SSH_AUTH_SOCK"]!=nil ){		
		[env setObject:[environmentDict objectForKey:@"SSH_AUTH_SOCK"] forKey:@"SSH_AUTH_SOCK"];
	}
	
	// This just sets up arguments to the ssh command. The first argument is a string of the form username@hostname and the second is a string with the actual command to be run on the host.
	NSMutableArray *args = [[NSMutableArray new] autorelease];
	[args addObject:@"-p 47499"];
	[args addObject:[NSString stringWithFormat:@"%@@%@",@"root",@"localhost"]];
	[args addObjectsFromArray:[command componentsSeparatedByString:@" "]];
	
	[sshTask setEnvironment:env]; 
	[sshTask setArguments:args];
	[sshTask setLaunchPath:@"/usr/bin/ssh"];
	
	
	// Before launching the task we get a filehandle for reading its output
	NSFileHandle * aReadHandle = [[sshTask standardOutput] fileHandleForReading];
	
	[sshTask launch];
	
	NSData * data = [aReadHandle readDataToEndOfFile];
	
	[sshTask release];
	
	return data;
}

-(void)run
{
	[self notifyBeginSubtask:@"Imaging the device" indefinite:NO];
	
	// create an output file
	NSFileManager * fm = [[[NSFileManager alloc] init] autorelease];
	[fm createFileAtPath:[imageFile path] contents:nil attributes:nil];
	
	// open it for writing
	NSError * error = nil;
	writeHandle = [NSFileHandle fileHandleForWritingToURL:imageFile error:&error];
	if(error)
	{
		NSLog(@"couldn't open output file");
	}
	[writeHandle retain];
	
	// figure out how many 1K blocks there are using df
	expectedSize = 0;
	receivedSize = 0;
	NSData * dfOutput = [self sshDoCommand:@"df"];
	NSString * dfResult = [[[NSString alloc] initWithData:dfOutput encoding:NSUTF8StringEncoding] autorelease];
	NSLog(@"%@", dfResult);
	NSArray * lines = [dfResult componentsSeparatedByString:@"\n"];
	for(NSString * line in lines)
	{
		if([line hasPrefix:@"/dev/disk0s2s1"])
		{
			line = [line stringByReplacingOccurrencesOfString:@"/dev/disk0s2s1" withString:@""];
			line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSArray * cols = [line componentsSeparatedByString:@" "];
			NSString * blocks = [cols objectAtIndex:0];
			expectedSize = [blocks longLongValue] * 1024;
			break;
		}
		if([line hasPrefix:@"/dev/disk0s1s2"])
		{
			line = [line stringByReplacingOccurrencesOfString:@"/dev/disk0s1s2" withString:@""];
			line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSArray * cols = [line componentsSeparatedByString:@" "];
			NSString * blocks = [cols objectAtIndex:0];
			expectedSize = [blocks longLongValue] * 1024;
			break;
		}
	}
	
	// use dd
	
	NSTask * sshTask = [[NSTask alloc] init];
	
	// Setup the pipes on the task
	NSPipe *outputPipe = [NSPipe pipe];
//	NSPipe *errorPipe = [NSPipe pipe];
	[sshTask setStandardOutput:outputPipe];
	// It's important that we set the standard input to null here. This is sometimes required in order to get SSH to use our Askpass program rather then prompt the user interactively. 
	[sshTask setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
	[sshTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	
	
	// Get the path of our Askpass program, which we've included as part of the main application bundle
	// This just spits out "alpine"
	NSString * askPassPath = [[NSBundle mainBundle] pathForResource:@"Askpass" ofType:@""];
	
	NSDictionary *environmentDict = [[NSProcessInfo processInfo] environment];
	// This creates a dictionary of environment variables (keys) and their values (objects) to be set in the environment where the task will be run. This environment dictionary will then be accessible to our Askpass program.
	NSMutableDictionary *env = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								@"NONE", @"DISPLAY", // It's important that Display is set so that ssh will use Askpass. The actual value is not important though 
								askPassPath, @"SSH_ASKPASS",
								nil];
	
	
	// This is necessary in order to allow key based login
	if ( [environmentDict objectForKey:@"SSH_AUTH_SOCK"]!=nil ){		
		[env setObject:[environmentDict objectForKey:@"SSH_AUTH_SOCK"] forKey:@"SSH_AUTH_SOCK"];
	}
	
	// This just sets up arguments to the ssh command. The first argument is a string of the form username@hostname and the second is a string with the actual command to be run on the host.
	NSMutableArray *args = [[NSMutableArray new] autorelease];
	[args addObject:@"-p 47499"];
	[args addObject:[NSString stringWithFormat:@"%@@%@",@"root",@"localhost"]];
	[args addObject:@"dd if=/dev/rdisk0s2s1 bs=8192 || dd if=/dev/rdisk0s1s2  bs=8192"];
	
	[sshTask setEnvironment:env]; 
	[sshTask setArguments:args];
	[sshTask setLaunchPath:@"/usr/bin/ssh"];
	
	// Before launching the task we get a filehandle for reading its output
	readHandle = [[sshTask standardOutput] fileHandleForReading];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(taskSentData:)
	                                             name:NSFileHandleReadCompletionNotification
	                                           object:readHandle];
	[readHandle readInBackgroundAndNotify];
	
	[sshTask launch];
	
	NSLog(@"starting read loop");
	while(!finished)
	{
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		[pool drain];
	}
	NSLog(@"ending loop (finished = YES)");
	
	[readHandle closeFile];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
	                                                name:NSFileHandleReadCompletionNotification 
	                                              object:readHandle];
	
	[sshTask release];
	
	// calculate sha-1 checksum of the image (using openssl) and log it
	[self notifyBeginSubtask:@"Calculating SHA1" indefinite:YES];
	
	NSMutableArray * sha1HashArgs = [NSMutableArray array];
	[sha1HashArgs addObject:@"openssl"];
	[sha1HashArgs addObject:@"sha1"];
	[sha1HashArgs addObject:[imageFile path]];
	
	sha1HashExec = [[KFExec alloc] initWithArgs:sha1HashArgs];
	stdOutData = [NSMutableData data];
	sha1HashExec.stdOutBlock = ^(NSData * data) {
		[stdOutData appendData:data];
	};
	[sha1HashExec launchWithCompletionBlock:^(void) {
		 sha1HashExecStatus = sha1HashExec.terminationStatus;
	}];
	[sha1HashExec waitForCompletion];
	
	// better way to append newline to NSData object directly?
	NSString * stdOutStr = [[[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding] autorelease];
	NSLog(@"%@", stdOutStr);
	NSString * logString = [NSString stringWithFormat:@"%@\n", stdOutStr];
	[acquisitionLog writeData:[logString dataUsingEncoding:NSUTF8StringEncoding]];
	
}

@end
