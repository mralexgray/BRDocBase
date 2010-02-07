//
//  DocBase.m
//  DocBase
//
//  Created by Neil Allain on 12/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DocBase.h"
#import <JSON/JSON.h>

#pragma mark --
#pragma mark Constants
NSString* const BRDocIdKey = @"_id";
NSString* const BRDocRevKey = @"_rev";
NSString* const BRDocTypeKey = @"_type";
NSString* const BRDocBaseExtension = @"docbase";
NSString* const BRDocBaseConfigBucketCount = @"bucketCount";

const NSUInteger BRDocDefaultBucketCount = 17;
static NSString* const BRDocExtension = @"doc.js";

#pragma mark error codes 
NSString* const BRDocBaseErrorDomain = @"com.blueropesoftware.docbase.ErrorDomain";
const NSInteger BRDocBaseErrorNotFound = 1;
const NSInteger BRDocBaseErrorNewDocumentNotSaved = 2;
const NSInteger BRDocBaseErrorConfigurationMismatch = 3;

#pragma mark --
#pragma mark Helper functions
static BOOL BRIsMutable(id<BRDocument> document);

#pragma mark --
#pragma mark Private interface

@interface BRDocBase()
-(NSNumber*)bucketForDocumentId:(NSString*)documentId;
-(NSString*)pathForBucket:(NSNumber*)bucket;
-(NSMutableDictionary*)documentsInBucket:(NSNumber*)bucket error:(NSError**)error;
-(BOOL)saveDocuments:(NSMutableDictionary*)documents inBucket:(NSNumber*)bucket error:(NSError**)error;
-(NSString*)serializeDocuments:(NSDictionary*)documents error:(NSError**)error;
-(NSMutableDictionary*)deserializeDocuments:(NSString*)documentData error:(NSError**)error;
-(NSDictionary*)translateToDictionary:(id<BRDocument>)document;
-(id<BRDocument>)translateToDocument:(NSDictionary*)dictionary;

-(BOOL)verifyEnvironment:(NSError**)error;
-(BOOL)readConfiguration:(NSError**)error;

-(NSError*)notFoundError:(NSString*)documentId;
-(NSError*)errorForDocumentId:(NSString*)documentId withCode:(NSInteger)errorCode;

@end

@implementation BRDocBase

#pragma mark --
#pragma mark Class Methods

+(NSString*)generateId
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	NSString* uuidString = (NSString*)CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	return [uuidString autorelease];
}

+(NSDictionary*)defaultConfiguration
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:BRDocDefaultBucketCount], BRDocBaseConfigBucketCount,
		nil];
}

#pragma mark -
#pragma mark Initialization

+(id)docBaseWithPath:(NSString *)path
{
	return [[[self alloc] initWithPath:path] autorelease];
}

+(id)docBaseWithPath:(NSString *)path configuration:(NSDictionary*)configuration
{
	return [[[self alloc] initWithPath:path configuration:configuration] autorelease];
}

-(id)initWithPath:(NSString *)path
{
	return [self initWithPath:path configuration:nil];
}

-(id)initWithPath:(NSString *)path configuration:(NSDictionary*)configuration
{
	self = [super init];
	_documentsInBucket = [[NSMutableDictionary alloc] init];
	_json = [[SBJSON alloc] init];
	_json.humanReadable = YES;
	_bucketCount = BRDocDefaultBucketCount;
	_configuration = [configuration copy];
	_environmentVerified = NO;
	if ([[path pathExtension] caseInsensitiveCompare:BRDocBaseExtension] != 0) {
		_path = [[path stringByAppendingPathExtension:BRDocBaseExtension] retain];
	} else {
		_path = [path copy];
	}
	return self;
}

-(void)dealloc
{
	[_json release], _json = nil;
	[_documentsInBucket release], _documentsInBucket = nil;
	[_path release], _path = nil;
	[_configuration release], _configuration = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark Public Properties
@synthesize path = _path;
@synthesize configuration = _configuration;

#pragma mark -
#pragma mark Public Methods
-(NSString*)saveDocument:(id<BRDocument>)document error:(NSError**)error
{
	if (![self verifyEnvironment:error]) return NO;
	NSString* documentId = [document documentId];
	// check isDocumentEdited
	if ([document respondsToSelector:@selector(isDocumentEdited)] &&
		![document isDocumentEdited]) {
		if ((documentId == nil) && (error != nil)) {
			// this is an odd situation, isDocumentEdited is false, but no id is set.
			// since we're returning nil, an error is set as well
			*error = [self errorForDocumentId:nil withCode:BRDocBaseErrorNewDocumentNotSaved];
		}
		return documentId;
	}
	// assign id if needed
	if (documentId == nil) {
		if (BRIsMutable(document)) {
			documentId = [BRDocBase generateId];
			[document setDocumentId:documentId];
		}
	}
	
	// save the document
	BOOL saved = NO;
	NSNumber* bucket = [self bucketForDocumentId:documentId];
	NSMutableDictionary* documentsInBucket = [self documentsInBucket:bucket error:error];
	if (documentsInBucket) {
		[documentsInBucket setObject:document forKey:documentId];
		saved = [self saveDocuments:documentsInBucket inBucket:bucket error:error];
		if (saved && [document respondsToSelector:@selector(setIsDocumentEdited:)]) {
			[document setIsDocumentEdited:NO];
		}
	}
	return saved ? documentId : nil;
}

-(id<BRDocument>)documentWithId:(NSString *)documentId error:(NSError**)error
{
	if (![self verifyEnvironment:error]) return NO;
	NSNumber* bucket = [self bucketForDocumentId:documentId];
	id<BRDocument> doc = [[self documentsInBucket:bucket error:error] objectForKey:documentId];
	if ((doc == nil) && (error)) {
		*error = [self notFoundError:documentId];
	}
	return doc;
}

-(BOOL)deleteDocumentWithId:(NSString *)documentId error:(NSError **)error
{
	if (![self verifyEnvironment:error]) return NO;
	BOOL deleted = NO;
	NSNumber* bucket = [self bucketForDocumentId:documentId];
	NSMutableDictionary* documentsInBucket = [self documentsInBucket:bucket error:error];
	if (documentsInBucket) {
		id<BRDocument> doc = [documentsInBucket objectForKey:documentId];
		if (doc) {
			[documentsInBucket removeObjectForKey:documentId];
			deleted = [self saveDocuments:documentsInBucket inBucket:bucket error:error];
		} else if (error) {
			*error = [self notFoundError:documentId];
		}
	}
	return deleted;
}

-(NSSet*)findDocumentsUsingPredicate:(NSPredicate*)predicate error:(NSError**)error
{
	if (![self verifyEnvironment:error]) return NO;
	BOOL success = YES;
	NSMutableSet* matchingDocuments = [NSMutableSet set];
	for (NSUInteger bucket = 0; bucket < _bucketCount; ++bucket) {
		NSDictionary* documentsInBucket = [self documentsInBucket:[NSNumber numberWithUnsignedInt:bucket] error:error];
		if (!documentsInBucket) {
			// an error occured
			success = NO;
			break;
		} else {
			[documentsInBucket enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
				@try {
					if ([predicate evaluateWithObject:value]) {
						[matchingDocuments addObject:value];
					}
				}
				@catch (NSException* e) {
					// ignore
				}
			}];
		}
	}
	return success ? matchingDocuments : nil;
}

-(void)environmentChanged
{
	_environmentVerified = NO;
}

#pragma mark Private implementation

-(NSString*)pathForBucket:(NSNumber*)bucket
{
	NSString* fileName = [NSString stringWithFormat:@"docs%@", bucket];
	return [[_path stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:BRDocExtension];
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
	NSString* serializedJson = [self serializeDocuments:documents error:error];
	if (serializedJson != nil) {
		saved = [serializedJson writeToFile:[self pathForBucket:bucket]
								 atomically:NO 
								   encoding:NSUTF8StringEncoding 
									  error:error];
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
	NSMutableArray* translatedDocuments = [NSMutableArray arrayWithCapacity:[documents count]];
	[documents enumerateKeysAndObjectsUsingBlock:^(id documentId, id document, BOOL* stop) {
		NSDictionary* documentDictionary = [self translateToDictionary:(id<BRDocument>)document];
		[translatedDocuments addObject:documentDictionary];
	}];
	return [_json stringWithObject:translatedDocuments error:error];
}

-(NSMutableDictionary*)deserializeDocuments:(NSString *)documentData error:(NSError **)error
{
	NSMutableDictionary* translatedDocuments = nil;
	NSArray* untranslatedDocuments = [_json objectWithString:documentData error:error];
	if (untranslatedDocuments) {
		translatedDocuments = [NSMutableDictionary dictionaryWithCapacity:[untranslatedDocuments count]];
		for (NSDictionary* documentDictionary in untranslatedDocuments) {
			id<BRDocument> document = [self translateToDocument:documentDictionary];
			if ([document respondsToSelector:@selector(setIsDocumentEdited:)]) {
				document.isDocumentEdited = NO;
			}
			[translatedDocuments setObject:document forKey:document.documentId];
		}
	}
	return translatedDocuments;
}

-(NSDictionary*)translateToDictionary:(id<BRDocument>)document
{
	NSDictionary* documentDictionary;
	if ([document isKindOfClass:[NSDictionary class]]) {
		documentDictionary = (NSDictionary*)document;
	} else {
		NSMutableDictionary* mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:[document documentDictionary]];
		[mutableDictionary setObject:NSStringFromClass([document class]) forKey:BRDocTypeKey];
		documentDictionary = mutableDictionary;
	}
	return documentDictionary;
}

-(id<BRDocument>)translateToDocument:(NSDictionary*)dictionary
{
	id<BRDocument> document = nil;
	if (dictionary != nil) {
		NSString* docType = [dictionary objectForKey:BRDocTypeKey];
		if (docType != nil) {
			Class docClass = NSClassFromString(docType);
			if (docClass != nil) {
				document = [[[docClass alloc] initWithDocumentDictionary:dictionary] autorelease];
			} else {
				NSLog(@"BRDocBase: unknown document type: %@", docType);
				document = dictionary;
			}
		} else {
			document = dictionary;
		}
	}
	return document;
}

-(BOOL)verifyEnvironment:(NSError **)error
{
	if (!_environmentVerified) {
		if (![[NSFileManager defaultManager] createDirectoryAtPath:self.path 
			withIntermediateDirectories:YES 
			attributes:nil error:error]) {
			return NO;
		}
		if (![self readConfiguration:error]) {
			return NO;
		}
		_environmentVerified = YES;
	}
	return _environmentVerified;
}

-(BOOL)readConfiguration:(NSError **)error
{
	NSString* configFilePath = [self.path stringByAppendingPathComponent:@"config.js"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:configFilePath]) {
		// no configuration exists, just write out the one we have
		if (!_configuration) _configuration = [[[self class] defaultConfiguration] copy];
		NSString* configData = [_json stringWithObject:self.configuration error:error];
		if (!configData) {
			// error converting to json
			return NO;
		}
		if (![configData writeToFile:configFilePath atomically:YES encoding:NSUTF8StringEncoding error:error]) {
			// error writing out file
			return NO;
		}
	} else {
		// config file exists, read it in
		NSString* configData = [NSString stringWithContentsOfFile:configFilePath encoding:NSUTF8StringEncoding error:error];
		if (!configData) {
			// error reading file
			return NO;
		}
		NSDictionary* readConfig = [_json objectWithString:configData error:error];
		if (!readConfig) {
			// error parsing json
			return NO;
		}
		if ((self.configuration != nil) && (![readConfig isEqualToDictionary:self.configuration])) {
			if (error) {
				*error = [[[NSError alloc] initWithDomain:BRDocBaseErrorDomain 
					code:BRDocBaseErrorConfigurationMismatch userInfo:nil] autorelease];
			}
			return NO;
		}
		// update configuration in case none was provided
		[_configuration release];
		_configuration = [readConfig copy];
		
	}

	// setup any configuration
	_bucketCount = [[self.configuration objectForKey:BRDocBaseConfigBucketCount] intValue];
	_bucketCount = _bucketCount <= 0 ? BRDocDefaultBucketCount : _bucketCount;
	
	return YES;
}

-(NSError*)notFoundError:(NSString *)documentId
{
	return [self errorForDocumentId:documentId withCode:BRDocBaseErrorNotFound];
}

-(NSError*)errorForDocumentId:(NSString*)documentId withCode:(NSInteger)errorCode
{
	return [[[NSError alloc] initWithDomain:BRDocBaseErrorDomain code:errorCode userInfo:nil] autorelease];
}

@end


#pragma mark --
#pragma mark Dictionary extensions

@implementation NSDictionary(BRDocument_Dictionary)

-(id)initWithDocumentDictionary:(NSDictionary*)dictionary
{
	return [self initWithDictionary:dictionary];
}

-(NSString*)documentId
{
	return [self objectForKey:BRDocIdKey];
}


-(void)setDocumentId:(NSString*)documentId
{
	NSMutableDictionary* mutable = (NSMutableDictionary*)self;
	[mutable setObject:documentId forKey:BRDocIdKey];
}

-(NSDictionary*)documentDictionary
{
	return self;
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

BOOL BRIsMutable(id<BRDocument> document)
{
	return [document respondsToSelector:@selector(setDocumentId:)];
}
