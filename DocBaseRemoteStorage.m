//
//  DocBaseRemoteStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/25/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseRemoteStorage.h"
#import <JSON/JSON.h>
#import "DocBaseDateExtensions.h"

#pragma mark -
#pragma mark Private Interface
@interface BRDocBaseRemoteStorage()
-(id)requestResource:(NSString*)resource error:(NSError**)error;
-(id)requestResource:(NSString *)resource method:(NSString*)method body:(id)body error:(NSError **)error;
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
	id response = [self
		requestResource:[NSString stringWithFormat:@"document/%@", documentId]
		method:@"PUT"
		body:document
		error:error];
	return response != nil;
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error
{
	id response = [self
		requestResource:[NSString stringWithFormat:@"document/%@", documentId]
		method:@"DELETE"
		body:nil
		error:error];
	return response != nil;
}

-(NSSet*)deletedDocumentIdsSinceDate:(NSDate*)date error:(NSError**)error
{
	NSString* dateString = [date docBaseString];
	dateString = (NSString *)CFURLCreateStringByAddingPercentEscapes(
		NULL,
		(CFStringRef)dateString,
		NULL,
		(CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
		kCFStringEncodingUTF8);
	[dateString autorelease];
	NSArray* documentIds = [self requestResource:[NSString stringWithFormat:@"deleted?date=%@", dateString] error:error];
	if (documentIds) {
		return [NSSet setWithArray:documentIds];
	}
	return nil;
}

#pragma mark -
#pragma mark Private implementation

-(id)requestResource:(NSString *)resource error:(NSError **)error
{
	return [self requestResource:resource method:@"GET" body:nil error:error];
}

-(id)requestResource:(NSString *)resource method:(NSString*)method body:(id)body error:(NSError **)error
{
	NSString* path = [_path stringByAppendingPathComponent:resource];
	NSURL* url = [NSURL URLWithString:path];
	NSMutableURLRequest* request = [NSMutableURLRequest 
		requestWithURL:url 
		cachePolicy:NSURLRequestUseProtocolCachePolicy 
		timeoutInterval:10.0];
	[request setHTTPMethod:method];
	if (body) {
		NSString* bodyString = [_json stringWithObject:body error:error];
		if (!bodyString) return nil;
		NSData* bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
		[request setHTTPBody:bodyData];
	}
	NSHTTPURLResponse* response = nil;
	NSData* responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
	if (responseData && ([response statusCode] == 200)) {
		NSString* responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
		return [_json objectWithString:responseString];
	}
	return nil;
}
@end
