//
//  AbstractDocBaseFileStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "AbstractDocBaseFileStorage.h"
#import <JSON/JSON.h>
#import "DocBase.h"
#import "DocBaseDateExtensions.h"

static NSString* const BRDocBaseDeletedDocumentsFile = @"deleted.js";
static NSString* const BRDocDeletedDateKey = @"deletedDate";

#pragma -
#pragma mark Private Interface

@interface BRAbstractDocBaseFileStorage()
-(BOOL)readDeletedFile:(NSError**)error;
-(BOOL)saveDeletedFile:(NSError**)error;
@end

@implementation BRAbstractDocBaseFileStorage

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
	[_deletedDocuments release], _deletedDocuments = nil;
	[_path release], _path = nil;
	[_json release], _json = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Properties

@synthesize path = _path;
@synthesize json = _json;

#pragma mark -
#pragma mark Public implementation

-(NSSet*)deletedDocumentIdsSinceDate:(NSDate*)date error:(NSError**)error
{
	if ([self readDeletedFile:error]) {
		NSDate* truncatedDate = [NSDate dateWithDocBaseString:[date docBaseString]];
		NSMutableSet* deletedDocumentIds = [NSMutableSet set];
		for (NSDictionary* deletedDocument in [_deletedDocuments allValues]) {
			NSDate* deletedDate = [NSDate dateWithDocBaseString:[deletedDocument objectForKey:BRDocDeletedDateKey]];
			if ([deletedDate laterDate:truncatedDate] == deletedDate) {
				[deletedDocumentIds addObject:[deletedDocument objectForKey:BRDocIdKey]];
			}
		}
		return deletedDocumentIds;
	}
	return nil;
}

-(BOOL)addedDocumentId:(NSString *)documentId error:(NSError **)error
{
	if (![self readDeletedFile:error]) return NO;
	[_deletedDocuments removeObjectForKey:documentId];
	return [self saveDeletedFile:error];
}

-(BOOL)deletedDocumentId:(NSString *)documentId date:(NSDate *)date error:(NSError**)error
{
	if (![self readDeletedFile:error]) return NO;
	NSDictionary* deletedDocument = [NSDictionary dictionaryWithObjectsAndKeys:
		documentId, BRDocIdKey,
		[date docBaseString], BRDocDeletedDateKey,
		nil];
	[_deletedDocuments setObject:deletedDocument forKey:documentId];
	return [self saveDeletedFile:error];
}

-(id)readJsonFile:(NSString *)path error:(NSError **)error
{
	NSString* jsonData = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
	if (!jsonData) {
		return nil;
	}
	return [self.json objectWithString:jsonData error:error];
}

-(BOOL)writeJson:(id)jsonObject toFile:(NSString *)path error:(NSError **)error
{
	NSString* serializedJson = [self.json stringWithObject:jsonObject error:error];
	if (!serializedJson) {
		return NO;
	}
	return [serializedJson writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

#pragma mark -
#pragma mark Private Implementation

-(BOOL)readDeletedFile:(NSError **)error
{
	if (_deletedDocuments) {
		return YES;
	}
	NSString* path = [self.path stringByAppendingPathComponent:BRDocBaseDeletedDocumentsFile];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSArray* deletedDocuments = [self readJsonFile:path error:error];
		if (deletedDocuments) {
			_deletedDocuments = [[NSMutableDictionary alloc] initWithCapacity:[deletedDocuments count]];
			for (NSDictionary* deletedDocument in deletedDocuments) {
				[_deletedDocuments setObject:deletedDocument forKey:[deletedDocument objectForKey:BRDocIdKey]];
			}
		}
	} else {
		_deletedDocuments = [[NSMutableDictionary alloc] init];
	}
	return _deletedDocuments != nil;
}

-(BOOL)saveDeletedFile:(NSError **)error
{
	NSString* path = [self.path stringByAppendingPathComponent:BRDocBaseDeletedDocumentsFile];
	return [self writeJson:[_deletedDocuments allValues] toFile:path error:error];
}

@end
