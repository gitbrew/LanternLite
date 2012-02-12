//
//  KFTaskAcquireKeys.m
//  LanternLite
//
//  Created by Author on 10/26/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTaskAcquireKeys.h"

@implementation KFTaskAcquireKeys

@synthesize keyFile;
@synthesize passcode;

-(id)init
{
	if(self = [super init])
	{
		self.taskName = @"Acquire Keys";
	}
	return self;
}

// copied in KFTaskAcquireImage... put somewhere better
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
	[args addObject:@"-o NoHostAuthenticationForLocalhost=yes"];
	//[args addObject:@"-o StrictHostKeyChecking=no"];
	//[args addObject:@"-o UserKnownHostsFile=/dev/null"];
	[args addObject:[NSString stringWithFormat:@"%@@%@",@"root",@"localhost"]];
	[args addObjectsFromArray:[command componentsSeparatedByString:@" "]];
	
	[sshTask setEnvironment:env]; 
	[sshTask setArguments:args];
	[sshTask setLaunchPath:@"/usr/bin/ssh"];
	
	
	// Before launching the task we get a filehandle for reading its output
	NSFileHandle * readHandle = [[sshTask standardOutput] fileHandleForReading];
	
	[sshTask launch];
	
	NSData * data = [readHandle readDataToEndOfFile];
	
	[sshTask release];
	
	return data;
}

-(void)run
{
	[self notifyBeginSubtask:@"Determining keys and passcode" indefinite:YES];
	[self sshDoCommand:@"/var/root/device_infos"];
	[self sshDoCommand:@"/var/root/bruteforce"];

	[self notifyBeginSubtask:@"Fetching keys" indefinite:YES];
	NSData * keyData = [self sshDoCommand:@"cat /var/root/keys.plist"];
	if(keyData == nil)
	{
		[self notifyErrorAndAbort:@"didn't get keys.plist from device"];
		return;
	}
	
	NSPropertyListFormat format = 0;
	id obj = [NSPropertyListSerialization propertyListWithData:keyData options:0 format:&format error:nil];
	if(obj && [obj isKindOfClass:[NSDictionary class]])
	{
		NSLog(@"got keys: %@", obj);
		NSDictionary * dict = (NSDictionary *) obj;
		[dict writeToURL:keyFile atomically:YES];
		
		self.passcode = [dict valueForKey:@"passcode"];
	}
}


@end
