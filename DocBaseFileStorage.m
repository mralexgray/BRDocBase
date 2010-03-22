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

-(void)dealloc
{
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
	// save the document to a copy in case there's an error
	NSMutableDictionary* documents = [[_documents mutableCopy] autorelease];
	[documents setObject:document forKey:documentId];
	if (![self writeToFile:documents error:error]) {
		return NO;
	}
	[_documents release];
	_documents = [documents retain];
	return YES;
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error
{
	if (![self readFromFile:error]) {
		return NO;
	}
	if (![_documents objectForKey:documentId]) {
		return NO;
	}
	if (![self deletedDocumentId:documentId date:date error:error]) {
		return NO;
	}
	// remove the document from a copy in case there's an error
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
	NSString* filePath = [self.path stringByAppendingPathComponent:BRDocBaseFileName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
		NSArray* documents = [self readJsonFile:filePath error:error];
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
	NSString* filePath = [self.path stringByAppendingPathComponent:BRDocBaseFileName];
	return [self writeJson:[documents allValues] toFile:filePath error:error];
}

@end
