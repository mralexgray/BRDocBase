//
//  DocBaseSyncRequest.m
//  DocBaseServer
//
//  Created by Neil Allain on 3/23/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseSyncRequest.h"
#import "DocBaseSyncServer.h"

@implementation BRDocBaseSyncRequest

#pragma mark -
#pragma mark Initialization

-(id)initWithServer:(BRDocBaseSyncServer*)server fileHandle:(NSFileHandle *)fileHandle
{
	self = [super init];
	_server = server;	// server is not retained
	_fileHandle = [fileHandle retain];
	_message = NULL;
	_complete = NO;
	_contentLength = 0;
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		selector:@selector(receivedDataNotification:)
		name:NSFileHandleReadCompletionNotification
		object:fileHandle];
	[fileHandle readInBackgroundAndNotify];
	return self;
}


-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (_message) CFRelease(_message);
	_message = NULL;
	[_fileHandle release], _fileHandle = nil;
	[_url release], _url = nil;
	[_method release], _method = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark Properties

@synthesize url = _url;
@synthesize fileHandle = _fileHandle;
@synthesize method = _method;

-(NSData*)body
{
	NSData* body = (NSData*)CFHTTPMessageCopyBody(_message);
	return [body autorelease];
}

-(NSDictionary*)queryParams
{
	NSMutableDictionary* params = [NSMutableDictionary dictionary];
	NSArray* pairs = [[self.url query] componentsSeparatedByString:@"&"];
	for (NSString* pair in pairs) {
		NSArray* keyValue = [pair componentsSeparatedByString:@"="];
		if ([keyValue count] == 2) {
			NSString* key = [keyValue objectAtIndex:0];
			NSString* value = [keyValue objectAtIndex:1];
			NSString* valueString = (NSString*)CFURLCreateStringByReplacingPercentEscapes(
				NULL, 
				(CFStringRef)value, 
				(CFStringRef)@"");
			[valueString autorelease];
			[params setObject:valueString forKey:key];
		}
	}
	return params;
}


#pragma mark -
#pragma mark Public methods

- (void)receivedDataNotification:(NSNotification *)notification
{
	NSData *data = [[notification userInfo] objectForKey:
					NSFileHandleNotificationDataItem];
    
	if ( [data length] == 0 ) {
		// NSFileHandle's way of telling us
		// that the client closed the connection
		[_server cancelRequest:self];
		// this will release the request, so do nothing after this
		return;
	} else {
		[_fileHandle readInBackgroundAndNotify];
        
		if(_message == NULL) {
            _message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
		}
		// still reading the header
		Boolean success = CFHTTPMessageAppendBytes(_message, (UInt8*)[data bytes],
												   [data length]);
		if (success) {
			if (_url == nil) {
				// still building the header
				if( CFHTTPMessageIsHeaderComplete(_message) ) {
					_url = (NSURL*)CFHTTPMessageCopyRequestURL(_message);
					_method = (NSString*)CFHTTPMessageCopyRequestMethod(_message);
					if ([_method isEqualToString:@"PUT"] || [_method isEqualToString:@"POST"]) {
						// continue reading up to content length
						NSString* contentLength = [((NSString*)CFHTTPMessageCopyHeaderFieldValue(_message, (CFStringRef)@"Content-Length")) autorelease];
						_contentLength = [contentLength intValue];
						NSLog(@"Incoming %@ request, content length: %d", _method, _contentLength);
					}
					if (_contentLength == 0) {
						_complete = YES;
					}
				}
			} 
			if (_url && _contentLength > 0) {
				// building the body
				NSData* body = (NSData*)CFHTTPMessageCopyBody(_message);
				if ([body length] >= _contentLength) {
					_complete = YES;
				}
				[body release];
			}
			if (_complete) {
				[_server handleRequest:self];
			}
			
		} else {
			NSLog(@"Incomming message not a HTTP header, ignored.");
			[_server cancelRequest:self];
		}	
	}
}
@end
