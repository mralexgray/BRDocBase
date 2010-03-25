//
//  DocBaseRemoteStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/25/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseRemoteStorage.h"
#import <JSON/JSON.h>

#pragma mark -
#pragma mark Private Interface
@interface BRDocBaseRemoteStorage()
-(id)requestResource:(NSString*)resource error:(NSError**)error;
@end

@implementation BRDocBaseRemoteStorage

#pragma mark -
#pragma mark Initialization

-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json
{
	self = [super init];
	_path = [path retain];
	_json = [json retain];
	return self;
}

-(void)dealloc
{
	[_path release], _path = nil;
	[_json release], _json = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark BRDocBaseStorage methods

-(NSMutableDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error
{
	return [self requestResource:[NSString stringWithFormat:@"document/%@", documentId] error:error];
}

-(NSSet*)allDocuments:(NSError**)error
{
	NSArray* documents = [self requestResource:@"document" error:error];
	return documents ? [NSSet setWithArray:documents] : nil;
}

-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error
{
	return NO;
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error
{
	return NO;
}

-(NSSet*)deletedDocumentIdsSinceDate:(NSDate*)date error:(NSError**)error
{
	return nil;
}

#pragma mark -
#pragma mark Private implementation

-(id)requestResource:(NSString *)resource error:(NSError **)error
{
	NSString* path = [_path stringByAppendingPathComponent:resource];
	NSURL* url = [NSURL URLWithString:path];
	NSURLRequest* request = [NSURLRequest 
		requestWithURL:url 
		cachePolicy:NSURLRequestUseProtocolCachePolicy 
		timeoutInterval:10.0];
	NSHTTPURLResponse* response = nil;
	NSData* responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
	if (responseData && ([response statusCode] == 200)) {
		NSString* responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
		return [_json objectWithString:responseString];
	}
	return nil;
}
@end
