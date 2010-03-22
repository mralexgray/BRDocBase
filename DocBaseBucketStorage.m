//
//  DocBaseBucketStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/14/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseBucketStorage.h"
#import "DocBase.h"
#import <JSON/JSON.h>

NSString* const BRDocBaseConfigBucketCount = @"bucketCount";

const NSUInteger BRDocDefaultBucketCount = 17;
static NSString* const BRDocExtension = @"doc.js";

#pragma mark -
#pragma mark Private interface

@interface BRDocBaseBucketStorage()
-(NSNumber*)bucketForDocumentId:(NSString*)documentId;
-(NSString*)pathForBucket:(NSNumber*)bucket;
-(NSMutableDictionary*)documentsInBucket:(NSNumber*)bucket error:(NSError**)error;
-(BOOL)saveDocuments:(NSMutableDictionary*)documents inBucket:(NSNumber*)bucket error:(NSError**)error;
-(NSString*)serializeDocuments:(NSDictionary*)documents error:(NSError**)error;
-(NSMutableDictionary*)deserializeDocuments:(NSString*)documentData error:(NSError**)error;
@end

@implementation BRDocBaseBucketStorage

#pragma mark -
#pragma mark Initialization
-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json
{
	self = [super initWithConfiguration:configuration path:path json:json];
	_documentsInBucket = [[NSMutableDictionary alloc] init];
	_bucketCount = [[configuration objectForKey:BRDocBaseConfigBucketCount] intValue];
	_bucketCount = _bucketCount <= 0 ? BRDocDefaultBucketCount : _bucketCount;
	return self;	
}


-(void)dealloc
{
	[_documentsInBucket release], _documentsInBucket = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark BRDocBaseStorage methods

-(NSMutableDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error
{
	NSNumber* bucket = [self bucketForDocumentId:documentId];
	return [[self documentsInBucket:bucket error:error] objectForKey:documentId];
}

-(NSSet*)allDocuments:(NSError**)error
{
	BOOL success = YES;
	NSMutableSet* allDocs = [NSMutableSet set];
	for (NSUInteger bucket = 0; bucket < _bucketCount; ++bucket) {
		NSDictionary* documentsInBucket = [self documentsInBucket:[NSNumber numberWithUnsignedInt:bucket] error:error];
		if (!documentsInBucket) {
			// an error occured
			success = NO;
			break;
		} else {
			[allDocs addObjectsFromArray:[documentsInBucket allValues]];
		}
	}
	return success ? allDocs : nil;
}

-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error
{
	BOOL saved = NO;
	NSNumber* bucket = [self bucketForDocumentId:documentId];
	NSMutableDictionary* documentsInBucket = [self documentsInBucket:bucket error:error];
	if (documentsInBucket) {
		[documentsInBucket setObject:document forKey:documentId];
		saved = [self saveDocuments:documentsInBucket inBucket:bucket error:error];
	}
	return saved;
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error
{
	BOOL deleted = NO;
	NSNumber* bucket = [self bucketForDocumentId:documentId];
	NSMutableDictionary* documentsInBucket = [self documentsInBucket:bucket error:error];
	if (documentsInBucket) {
		NSDictionary* doc = [documentsInBucket objectForKey:documentId];
		if (doc) {
			if ([self deletedDocumentId:documentId date:date error:error]) {
				[documentsInBucket removeObjectForKey:documentId];
				deleted = [self saveDocuments:documentsInBucket inBucket:bucket error:error];
				// really we need to undo the deleted document id here
			}
		}
	}
	return deleted;
}

#pragma mark -
#pragma mark Private Implementation

-(NSString*)pathForBucket:(NSNumber*)bucket
{
	NSString* fileName = [NSString stringWithFormat:@"docs%@", bucket];
	return [[self.path stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:BRDocExtension];
}

-(NSMutableDictionary*)documentsInBucket:(NSNumber *)bucket error:(NSError**)error
{
	NSMutableDictionary* documentsInBucket = [_documentsInBucket objectForKey:bucket];
	if (documentsInBucket == nil) {
		NSString* bucketFile = [self pathForBucket:bucket];
		if ([[NSFileManager defaultManager] fileExistsAtPath:bucketFile]) {
			NSString* serializedJson = [NSString stringWithContentsOfFile:bucketFile encoding:NSUTF8StringEncoding error:error];
			documentsInBucket = [self deserializeDocuments:serializedJson error:error];
		} else {
			documentsInBucket = [NSMutableDictionary dictionary];
		}
		[_documentsInBucket setObject:documentsInBucket forKey:bucket];
	}
	return documentsInBucket;
}

-(BOOL)saveDocuments:(NSMutableDictionary*)documents inBucket:(NSNumber*)bucket error:(NSError**)error
{
	BOOL saved = NO;
	NSString* bucketFile = [self pathForBucket:bucket];
	if ([documents count] > 0) {
		NSString* serializedJson = [self serializeDocuments:documents error:error];
		if (serializedJson != nil) {
			saved = [serializedJson 
					 writeToFile:bucketFile
					 atomically:NO 
					 encoding:NSUTF8StringEncoding 
					 error:error];
		}
	} else {
		// no documents in the file, delete the file instead
		if ([[NSFileManager defaultManager] fileExistsAtPath:bucketFile]) {
			saved = [[NSFileManager defaultManager] removeItemAtPath:bucketFile error:error];
		} else {
			// nothing to save
			saved = YES;
		}
	}
	return saved;
}


-(NSNumber*)bucketForDocumentId:(NSString *)documentId
{
	NSUInteger bucketForDocument = [documentId documentIdHash] % _bucketCount;
	return [NSNumber numberWithUnsignedInt:bucketForDocument];
}

-(NSString*)serializeDocuments:(NSDictionary*)documents error:(NSError**)error
{
	return [self.json stringWithObject:[documents allValues] error:error];
}

-(NSMutableDictionary*)deserializeDocuments:(NSString *)documentData error:(NSError **)error
{
	NSMutableDictionary* documentsById = nil;
	NSArray* documents = [self.json objectWithString:documentData error:error];
	if (documents) {
		documentsById = [NSMutableDictionary dictionaryWithCapacity:[documents count]];
		for (NSDictionary* documentDictionary in documents) {
			NSString* documentId = [documentDictionary objectForKey:BRDocIdKey];
			if (documentId) {
				[documentsById setObject:documentDictionary forKey:documentId];
			} else {
				NSLog(@"discarding document due to lack of document id:\n%@", documentDictionary);
			}
		}
	}
	return documentsById;
}

@end


#pragma mark -
#pragma mark String extensions

@implementation NSString(BRDocBase_String)

#define FNV_32_PRIME ((Fnv32_t)0x01000193)

-(NSUInteger)documentIdHash
{
	NSUInteger hval = 2166136261;
	const NSUInteger fnvPrime = 0x01000193;
    const unsigned char *s = (const unsigned char *)[self UTF8String];	/* unsigned string */
	
    /*
     * FNV-1 hash each octet in the buffer
     */
    while (*s) {
		
		hval *= fnvPrime;
		hval ^= (NSUInteger)*s++;
    }
    return hval;
}

@end

