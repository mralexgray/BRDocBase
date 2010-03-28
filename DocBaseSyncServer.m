//
//  DocBaseSyncServer.m
//  DocBaseServer
//
//  Created by Neil Allain on 3/23/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseSyncServer.h"
#import "DocBaseSyncRequest.h"
#import "DocBase.h"
#import "DocBaseSyncResponse.h"
#import "DocBaseDateExtensions.h"
#import <JSON/JSON.h>
#import <netinet/in.h>
#import <sys/socket.h>

NSString* const BRDocBaseSyncDocumentAddedNotification = @"BRDocBaseSyncDocumentAddedNotification";
NSString* const BRDocBaseSyncDocumentUpdatedNotification = @"BRDocBaseSyncDocumentUpdatedNotification";
NSString* const BRDocBaseSyncDocumentDeletedNotification = @"BRDocBaseSyncDocumentDeletedNotification";


#pragma mark -
#pragma mark Private Interface

@interface BRDocBaseSyncServer() <NSNetServiceDelegate>
-(BRDocBaseSyncResponse*)getDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error;
-(BRDocBaseSyncResponse*)putDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error;
-(BRDocBaseSyncResponse*)deleteDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error;
-(BRDocBaseSyncResponse*)findDocuments:(BRDocBaseSyncRequest*)request error:(NSError**)error;
-(BRDocBaseSyncResponse*)findDeletedDocuments:(BRDocBaseSyncRequest*)request error:(NSError**)error;

-(NSInteger)portForSocket;

@end

@implementation BRDocBaseSyncServer

#pragma mark -
#pragma mark Initialization

-(id)initWithDocBase:(BRDocBase*)docBase;
{
	self = [super init];
	_json = [[SBJSON alloc] init];
	_docBase = [docBase retain];
	_requests = [[NSMutableSet alloc] init];
	_serviceType = [[NSString alloc] initWithString:@"_docbase._tcp"];
	_serviceName = [[NSString alloc] initWithString:@"DocBaseSyncServer"];
	return self;
}

-(void)dealloc
{
	[self stop];
	[_requests release], _requests = nil;
	[_json release], _json = nil;
	[super dealloc];
}

#pragma mark Properties

@synthesize serviceType = _serviceType;
@synthesize serviceName = _serviceName;

#pragma mark -
#pragma mark Public methods
-(void)start
{
	if (!_socketPort) {
		//_socketPort = [[NSSocketPort alloc] initWithTCPPort:_portNumber];
		_socketPort = [[NSSocketPort alloc] init];
		int fd = [_socketPort socket];
		_fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd
													closeOnDealloc:YES];
		
		[[NSNotificationCenter defaultCenter] 
		 addObserver:self
		 selector:@selector(newConnection:)
		 name:NSFileHandleConnectionAcceptedNotification
		 object:nil];
		
		[_fileHandle acceptConnectionInBackgroundAndNotify];
		
		NSInteger port = [self portForSocket];
		NSLog(@"publishing net service: %@, port: %d, type: %@", self.serviceName, port, self.serviceType);
		_netService = [[NSNetService alloc] initWithDomain:@"local." type:self.serviceType name:self.serviceName port:port];
		[_netService setDelegate:self];
		[_netService publish];
	}
}

-(void)stop
{
	[_netService stop];
	[_netService release], _netService = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_fileHandle release], _fileHandle = nil;
	[_socketPort release], _socketPort = nil;
}

-(void)cancelRequest:(BRDocBaseSyncRequest *)request
{
	[_requests removeObject:request];
}

-(void)handleRequest:(BRDocBaseSyncRequest *)request
{
	BRDocBaseSyncResponse* response = nil;
	NSError* error = nil;
	NSLog(@"handling request: %@ %@", request.method, request.url);
	if ([[request.url path] hasPrefix:@"/document/"]) {
		if ([request.method isEqualToString:@"GET"]) {
			response = [self getDocument:request error:&error];
		} else if ([request.method isEqualToString:@"PUT"]) {
			response = [self putDocument:request error:&error];
		} else if ([request.method isEqualToString:@"DELETE"]) {
			response = [self deleteDocument:request error:&error];
		}
	} else if ([[request.url path] isEqualToString:@"/document"] && 
		[request.method isEqualToString:@"GET"]) {
		response = [self findDocuments:request error:&error];
	} else if ([[request.url path] hasPrefix:@"/deleted"] &&
		[request.method isEqualToString:@"GET"]) {
		response = [self findDeletedDocuments:request error:&error];
	}

	if (error) {
		response = [BRDocBaseSyncResponse docBaseSyncResponseWithCode:500 body:nil];
	}

	if (!response) {
		response = [BRDocBaseSyncResponse docBaseSyncResponseWithCode:404 body:nil];
	}	
	
	NSData* jsonData = nil;
	CFIndex responseCode = response.code;
	if (response.body) {
		NSString* jsonString = [_json stringWithObject:response.body error:&error];
		if (!jsonString) {
			responseCode = 500;
		} else {
			jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
		}
	}
	
	CFHTTPMessageRef httpResponse = CFHTTPMessageCreateResponse(
		kCFAllocatorDefault, responseCode, NULL, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(
		httpResponse, (CFStringRef)@"Content-Type", (CFStringRef)@"text/plain");
	CFHTTPMessageSetHeaderFieldValue(
		httpResponse, (CFStringRef)@"Connection", (CFStringRef)@"close");
	CFHTTPMessageSetHeaderFieldValue(
		httpResponse,
		(CFStringRef)@"Content-Length",
		(CFStringRef)[NSString stringWithFormat:@"%ld", [jsonData length]]);
	CFDataRef headerData = CFHTTPMessageCopySerializedMessage(httpResponse);
	
	@try
	{
		[request.fileHandle writeData:(NSData *)headerData];
		if (jsonData) {
			[request.fileHandle writeData:jsonData];
		}
	}
	@catch (NSException *exception)
	{
		// Ignore the exception, it normally just means the client
		// closed the connection from the other end.
	}
	@finally
	{
		CFRelease(headerData);
		[_requests removeObject:request];
	}
}

-(void)newConnection:(NSNotification*)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSFileHandle *remoteFileHandle = [userInfo objectForKey:
									  NSFileHandleNotificationFileHandleItem];
	
	NSNumber *errorNo = [userInfo objectForKey:@"NSFileHandleError"];
	if( errorNo ) {
		NSLog(@"NSFileHandle Error: %@", errorNo);
		return;
	}
	
	[_fileHandle acceptConnectionInBackgroundAndNotify];
	
	if( remoteFileHandle ) {
		BRDocBaseSyncRequest* request = [[[BRDocBaseSyncRequest alloc] initWithServer:self fileHandle:remoteFileHandle] autorelease];
		[_requests addObject:request];
	}
}


#pragma mark -
#pragma mark request handlers

-(id<BRDocument>)getRequestedDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error
{
	NSString* documentId = [[request.url path] substringFromIndex:10];
	NSLog(@"Retrieving documentId: %@", documentId);
	return [_docBase documentWithId:documentId error:error];
}

-(BRDocBaseSyncResponse*)getDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error
{
	NSError* localError;
	id<BRDocument> doc = [self getRequestedDocument:request error:&localError];
	if (doc) {
		return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:200 body:[doc documentDictionary]];
	} else if ([localError code] == BRDocBaseErrorNotFound) {
		return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:404 body:nil];
	}
	if (error) *error = localError;
	return nil;
}

-(BRDocBaseSyncResponse*)putDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error
{
	NSString* jsonString = [[[NSString alloc] initWithData:request.body encoding:NSUTF8StringEncoding] autorelease];
	id jsonObj = [_json objectWithString:jsonString error:error];
	if (!jsonObj) return nil;
	id<BRDocument> document = [_docBase translateToDocument:jsonObj];
	if ([document respondsToSelector:@selector(setIsDocumentEdited:)]) {
		document.isDocumentEdited = YES;
	}
	NSString* notification;
	if ([_docBase documentWithId:document.documentId error:nil] != nil) {
		notification = BRDocBaseSyncDocumentUpdatedNotification;
	} else {
		notification = BRDocBaseSyncDocumentAddedNotification;
	}
	if (![_docBase saveDocument:document updateModificationDate:NO error:error]) return nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:notification object:self];
	return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:200 body:nil];
}

-(BRDocBaseSyncResponse*)deleteDocument:(BRDocBaseSyncRequest*)request error:(NSError**)error
{
	NSError* localError;
	id<BRDocument> doc = [self getRequestedDocument:request error:&localError];
	if (doc){
		if ([_docBase deleteDocumentWithId:doc.documentId error:error]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:BRDocBaseSyncDocumentDeletedNotification object:self];
			return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:200 body:nil];
		}
	} else if ([localError code] == BRDocBaseErrorNotFound) {
		return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:404 body:nil];
	}
	if (error) *error = localError;
	return nil;
}

-(BRDocBaseSyncResponse*)findDocuments:(BRDocBaseSyncRequest*)request error:(NSError**)error
{
	// retrieve all documents
	NSLog(@"findDocuments");
	NSSet* documents = [_docBase findDocumentsUsingPredicate:[NSPredicate predicateWithValue:YES] error:error];
	if (documents) {
		NSMutableArray* dictionaries = [NSMutableArray arrayWithCapacity:[documents count]];
		for (id<BRDocument> doc in documents) {
			[dictionaries addObject:[doc documentDictionary]];
		}
		return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:200 body:dictionaries];
	}
	return nil;
}

//static NSString* const BRUrlEncodedCharacters = @"!*'\"();:@&=+$,/?%#[]% ";
-(BRDocBaseSyncResponse*)findDeletedDocuments:(BRDocBaseSyncRequest*)request error:(NSError**)error
{
	NSDate* deletedSince = [NSDate distantPast];
	NSMutableDictionary* params = [NSMutableDictionary dictionary];
	NSArray* pairs = [[request.url query] componentsSeparatedByString:@"&"];
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
	NSString* dateString = [params objectForKey:@"date"];
	if (dateString) {
		deletedSince = [NSDate dateWithDocBaseString:dateString];
	}
	NSLog(@"findDeletedDocuments: %@", deletedSince);
	NSSet* deletedDocumentIds = [_docBase deletedDocumentIdsSinceDate:deletedSince error:error];
	if (deletedDocumentIds == nil) return nil;
	return [BRDocBaseSyncResponse docBaseSyncResponseWithCode:200 body:[deletedDocumentIds allObjects]];
}


-(NSInteger)portForSocket
{
	NSInteger port;
	struct sockaddr* addr = (struct sockaddr *)[[_socketPort address] bytes];
    if(addr->sa_family == AF_INET)
    {
        port = ntohs(((struct sockaddr_in *)addr)->sin_port);
    }
    else if(addr->sa_family == AF_INET6)
    {
        port = ntohs(((struct sockaddr_in6 *)addr)->sin6_port);
    }
	return port;
}
@end
