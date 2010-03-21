//
//  DocBaseFileStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/15/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseFileStorage.h"
#import <JSON/JSON.h>
#import "DocBase.h"

static NSString* const BRDocBaseFileName = @"docbase_data.js";

#pragma mark -
#pragma mark Private Interface
@interface BRDocBaseFileStorage()
-(BOOL)readFromFile:(NSError**)error;
-(BOOL)writeToFile:(NSDictionary*)document error:(NSError**)error;
@end

@implementation BRDocBaseFileStorage

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
	[_documents release], _documents = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark BRDocBaseStorage methods

-(NSMutableDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error
{
	if ([self readFromFile:error]) {
		return [_documents objectForKey:documentId];
	}
	return nil;
}

-(NSSet*)allDocuments:(NSError**)error
{
	if ([self readFromFile:error]) {
		return [NSSet setWithArray:[_documents allValues]];
	}
	return nil;
}

-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error
{
	if (![self readFromFile:error]) {
		return NO;
	}
	NSMutableDictionary* documents = [[_documents mutableCopy] autorelease];
	[documents setObject:document forKey:documentId];
	if (![self writeToFile:documents error:error]) {
		return NO;
	}
	[_documents release];
	_documents = [documents retain];
	return YES;
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId error:(NSError**)error
{
	if (![self readFromFile:error]) {
		return NO;
	}
	if (![_documents objectForKey:documentId]) {
		return NO;
	}
	NSMutableDictionary* documents = [[_documents mutableCopy] autorelease];
	[documents removeObjectForKey:documentId];
	if (![self writeToFile:documents error:error]) {
		return NO;
	}
	[_documents release];
	_documents = [documents retain];
	return YES;
}

#pragma mark -
#pragma mark Private methods

-(BOOL)readFromFile:(NSError**)error
{
	if (_documents) {
		return YES;
	}
	NSString* filePath = [_path stringByAppendingPathComponent:BRDocBaseFileName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
		NSString* serializedDocuments = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:error];
		if (!serializedDocuments) {
			return NO;
		}
		NSArray* documents = [_json objectWithString:serializedDocuments error:error];
		if (!documents) {
			return NO;
		}
		_documents = [[NSMutableDictionary alloc] initWithCapacity:[documents count]];
		for (NSDictionary* dictionary in documents) {
			NSString* documentId = [dictionary objectForKey:BRDocIdKey];
			[_documents setObject:dictionary forKey:documentId];
		}
	} else {
		_documents = [[NSMutableDictionary alloc] init];
	}
	return YES;
}

-(BOOL)writeToFile:(NSDictionary*)documents error:(NSError**)error
{
	NSString* serializedDocuments = [_json stringWithObject:[documents allValues] error:error];
	if (!serializedDocuments) {
		return NO;
	}
	NSString* filePath = [_path stringByAppendingPathComponent:BRDocBaseFileName];
	return [serializedDocuments writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
