//
//  KFTaskDecryptImage.m
//  LanternLite
//
//  Created by Author on 10/21/11.
//  Copyright 2011 Katana Forensics, Inc. All rights reserved.
//

#import "KFTaskDecryptImage.h"

@implementation KFTaskDecryptImage

@synthesize imageFile;
@synthesize keyFile;
@synthesize outFile;
@synthesize logDir;

-(id)init
{
	if(self = [super init])
	{
		self.taskName = @"Decrypt Data Partition Image";
	}
	return self;
}

-(BOOL)canStart
{
	NSFileManager * fm = [[[NSFileManager alloc] init] autorelease];
	if(![fm fileExistsAtPath:[imageFile path]]) return NO;
	if(![fm fileExistsAtPath:[keyFile path]]) return NO;
	return [super canStart];
}

-(void)run
{
	NSLog(@"Cleaning up any previous decryption attempt");
	if([[NSFileManager defaultManager] isReadableFileAtPath:[outFile path]])
	{	
		[[NSFileManager defaultManager] removeItemAtURL:outFile error:nil];
	}
	NSLog(@"Cleanup finished");
	
	// Make a copy of image into folder for decrypted files. Image is then decrypted in place
	[self notifyBeginSubtask:@"Copying data partition image into working directory" indefinite:YES];

	if([[NSFileManager defaultManager] isReadableFileAtPath:[imageFile path]])
	{	
		[[NSFileManager defaultManager] copyItemAtURL:imageFile toURL:outFile error:nil];
	}
	else
	{
		[self notifyErrorAndAbort:@"Unable to read data partition image"];
	}
	
	// Create log files and open for writing
	[[NSFileManager defaultManager] createFileAtPath:[[logDir URLByAppendingPathComponent:@"decryption_err_log.txt"] path] contents:nil attributes:nil];
	[[NSFileManager defaultManager] createFileAtPath:[[logDir URLByAppendingPathComponent:@"decryption_log.txt"] path] contents:nil attributes:nil];
	
	NSError * error = nil;
	decryptErrLogWriteHandle = [NSFileHandle fileHandleForWritingToURL:[logDir URLByAppendingPathComponent:@"decryption_err_log.txt"] error:&error];
	if(error)
	{
		NSLog(@"couldn't open output file");
	}
	decryptLogWriteHandle = [NSFileHandle fileHandleForWritingToURL:[logDir URLByAppendingPathComponent:@"decryption_log.txt"] error:&error];
	error = nil;
	if(error)
	{
		NSLog(@"couldn't open output file");
	}
	
	// TODO: perform a test decryption first to see if it will work
	
	[self notifyBeginSubtask:@"Decrypting Image" indefinite:YES];

	NSArray * emfDecrypterArgs = [NSArray arrayWithObject:[outFile path]];
	emfDecrypterExec = [[KFExec alloc] initWithBundledPythonScript:@"emf_decrypter" arguments:emfDecrypterArgs];
	
	// Set up logging
	emfDecrypterExec.stdErrBlock = ^(NSData * data) {
		[decryptErrLogWriteHandle writeData:data];
	};
	emfDecrypterExec.stdOutBlock = ^(NSData * data) {
		[decryptLogWriteHandle writeData:data];
	};

	// Start decryption
	[emfDecrypterExec launchWithCompletionBlock:^(void) {
		NSLog(@"%@ exited with %d", emfDecrypterExec.executablePath, emfDecrypterExec.terminationStatus);
	}];

	NSLog(@"Waiting for decryption to complete");
	[emfDecrypterExec waitForCompletion];
	
	// Clean up log files
	[decryptErrLogWriteHandle synchronizeFile];
	[decryptLogWriteHandle synchronizeFile];
	[decryptErrLogWriteHandle closeFile];
	[decryptLogWriteHandle closeFile];	
}

-(void)dealloc
{
	self.imageFile = nil;
	self.keyFile = nil;
	self.outFile = nil;
	self.logDir = nil;
	[super dealloc];
}

@end
