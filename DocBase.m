//
//  DocBase.m
//  DocBase
//
//  Created by Neil Allain on 12/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DocBase.h"
#import "DocBaseBucketStorage.h"
#import "DocBaseDateExtensions.h"
#import "DocBaseDictionaryExtensions.h"

#import <JSON/JSON.h>

#pragma mark --
#pragma mark Constants
NSString* const BRDocIdKey = @"_id";
NSString* const BRDocRevKey = @"_rev";
NSString* const BRDocTypeKey = @"_type";
NSString* const BRDocModificationDateKey = @"_modificationDate";
NSString* const BRDocBaseExtension = @"docbase";
NSString* const BRDocBaseConfigStorageType = @"storageType";
NSString* const BRDocBaseDefaultStorageType = @"BRDocBaseBucketStorage";

#pragma mark error codes 
NSString* const BRDocBaseErrorDomain = @"com.blueropesoftware.docbase.ErrorDomain";
const NSInteger BRDocBaseErrorNotFound = 1;
const NSInteger BRDocBaseErrorNewDocumentNotSaved = 2;
const NSInteger BRDocBaseErrorConfigurationMismatch = 3;
const NSInteger BRDocBaseErrorUnknownStorageType = 4;

#pragma mark --
#pragma mark Helper functions

#pragma mark --
#pragma mark Private interface

@interface BRDocBase()

-(void)makeBundle:(BOOL)isBundle;
-(BOOL)readConfiguration:(NSError**)error;

-(BOOL)initializeStorage:(NSError**)error;

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
		BRDocBaseDefaultStorageType, BRDocBaseConfigStorageType,
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
	_documentsById = [[NSMutableDictionary alloc] init];
	_json = [[SBJSON alloc] init];
	_json.humanReadable = YES;
	_configuration = [configuration copy];
	_isRemote = [[_configuration objectForKey:BRDocBaseConfigStorageType]
		isEqualToString:@"BRDocBaseRemoteStorage"];
	_environmentVerified = NO;
	if (!_isRemote && ([[path pathExtension] caseInsensitiveCompare:BRDocBaseExtension] != 0)) {
		_path = [[path stringByAppendingPathExtension:BRDocBaseExtension] retain];
	} else {
		_path = [path copy];
	}
	return self;
}

-(void)dealloc
{
	[_documentsById release], _documentsById = nil;
	[_json release], _json = nil;
	[_path release], _path = nil;
	[_configuration release], _configuration = nil;
	[_storage release], _storage = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Public Properties
@synthesize path = _path;
@synthesize configuration = _configuration;

#pragma mark -
#pragma mark Public Methods

-(BOOL)verifyEnvironment:(NSError **)error
{
	if (!_environmentVerified) {
		if (!_isRemote) {
			if (![[NSFileManager defaultManager]
				createDirectoryAtPath:self.path 
				withIntermediateDirectories:YES 
				attributes:nil error:error]) {
				return NO;
			}
			[self makeBundle:YES];
			if (![self readConfiguration:error]) {
				return NO;
			}
		} else {
			if (![self initializeStorage:error]) {
				return NO;
			}
		}
		_environmentVerified = YES;
	}
	return _environmentVerified;
}


-(NSString*)saveDocument:(id<BRDocument>)document error:(NSError**)error
{
	return [self saveDocument:document updateModificationDate:YES error:error];
}

-(NSString*)saveDocument:(id<BRDocument>)document updateModificationDate:(BOOL)updateModificationDate error:(NSError**)error
{
	if (![self verifyEnvironment:error]) return nil;
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
		documentId = [BRDocBase generateId];
		[document setDocumentId:documentId];
	}
	
	// set modification date if needed
	if (updateModificationDate && [document respondsToSelector:@selector(setModificationDate:)]) {
		document.modificationDate = [NSDate docBaseDate];
	}
	// save the document
	NSDictionary* dictionary = [self translateToDictionary:document];
	BOOL saved = [_storage saveDocument:dictionary withDocumentId:documentId error:error];
	if (saved) {
		if ([document respondsToSelector:@selector(setIsDocumentEdited:)]) {
			[document setIsDocumentEdited:NO];
		}
		[_documentsById setObject:document forKey:documentId];
	}
	return saved ? documentId : nil;
}

-(id<BRDocument>)documentWithId:(NSString *)documentId error:(NSError**)error
{
	id<BRDocument> doc = nil;
	if (![self verifyEnvironment:error]) return nil;
	doc = [_documentsById objectForKey:documentId];
	if (!doc) {
		NSMutableDictionary* dictionary = [_storage documentWithId:documentId error:error];
		if (!dictionary && (error) && (*error == nil)) {
			*error = [self notFoundError:documentId];
		}
		if (dictionary) {
			doc = [self translateToDocument:dictionary];
			[_documentsById setObject:doc forKey:documentId];
		}
	}

	return doc;
}

-(BOOL)deleteDocumentWithId:(NSString *)documentId error:(NSError **)error
{
	if (![self verifyEnvironment:error]) return NO;
	NSDate* date = [NSDate date];
	BOOL deleted = [_storage deleteDocumentWithId:documentId date:date error:error];
	if (!deleted && error && (*error == nil)) {
		*error = [self notFoundError:documentId];
	}
	if (deleted) {
		[_documentsById removeObjectForKey:documentId];
	}
	return deleted;
}

-(NSSet*)findDocumentsUsingPredicate:(NSPredicate*)predicate error:(NSError**)error
{
	if (![self verifyEnvironment:error]) return nil;
	NSMutableSet* matchingDocuments = nil;
	NSSet* allDocs = [_storage allDocuments:error];
	if (allDocs) {
		matchingDocuments = [NSMutableSet set];
		for (NSMutableDictionary* dictionary in allDocs) {
			NSString* documentId = [dictionary objectForKey:BRDocIdKey];
			id<BRDocument> document = [_documentsById objectForKey:documentId];
			if (!document) {
				document = [self translateToDocument:dictionary];
				[_documentsById setObject:document forKey:documentId];
			}
			@try {
				if ([predicate evaluateWithObject:document]) {
					[matchingDocuments addObject:document];
				}
			}
			@catch (NSException* e) {
				// ignore
			}
		}
	}
	return matchingDocuments;
}

-(NSSet*)deletedDocumentIdsSinceDate:(NSDate *)date error:(NSError **)error
{
	if (![self verifyEnvironment:error]) return nil;
	if (date == nil) date = [NSDate distantPast];
	return [_storage deletedDocumentIdsSinceDate:date error:error];
}

-(void)environmentChanged
{
	_environmentVerified = NO;
	[_storage release], _storage = nil;
}

#pragma mark Private implementation

-(void)makeBundle:(BOOL)isBundle
{
#if TARGET_OS_MAC && !(TARGET_OS_IPHONE || TARGET_OS_EMBEDDED)
	NSURL* url = [NSURL URLWithString:self.path];
	[url setResourceValue:[NSNumber numberWithBool:isBundle] forKey:NSURLIsPackageKey error:nil];
#endif
}


-(NSDictionary*)translateToDictionary:(id<BRDocument>)document
{
	NSDictionary* documentDictionary = [document documentDictionary];
	if ((![document isKindOfClass:[NSDictionary class]]) && ([documentDictionary objectForKey:BRDocTypeKey] == nil)) {
		// add the type key
		NSMutableDictionary* mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:documentDictionary];
		[mutableDictionary setObject:NSStringFromClass([document class]) forKey:BRDocTypeKey];
		documentDictionary = mutableDictionary;
	}
	NSAssert([documentDictionary objectForKey:BRDocIdKey], @"Document Dictionary has no _id set");
	return documentDictionary;
}

-(id<BRDocument>)translateToDocument:(NSMutableDictionary*)dictionary
{
	id<BRDocument> document = nil;
	if (dictionary != nil) {
		NSString* docType = [dictionary objectForKey:BRDocTypeKey];
		if (docType != nil) {
			Class docClass = NSClassFromString(docType);
			if (docClass != nil) {
				document = [[[docClass alloc] initWithDocumentDictionary:dictionary] autorelease];
				if ([document respondsToSelector:@selector(setIsDocumentEdited:)]) {
					[document setIsDocumentEdited:NO];
				}
			} else {
				NSLog(@"BRDocBase: unknown document type: %@", docType);
				document = [dictionary mutableCopy];
			}
		} else {
			document = [dictionary mutableCopy];
		}
	}
	return document;
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

	// setup the storage
	return [self initializeStorage:error];
}

-(BOOL)initializeStorage:(NSError **)error
{
	NSString* storageType = [self.configuration objectForKey:BRDocBaseConfigStorageType];
	if (!storageType) storageType = BRDocBaseDefaultStorageType;
	Class storageClass = NSClassFromString(storageType);
	if ((storageClass == nil) ||
		(![storageClass conformsToProtocol:@protocol(BRDocBaseStorage)])) {
		if (error) {
			*error = [[[NSError alloc] 
					   initWithDomain:BRDocBaseErrorDomain 
					   code:BRDocBaseErrorUnknownStorageType 
					   userInfo:nil] 
					  autorelease];
		}
		return NO;
	}
	_storage = [[storageClass alloc] initWithConfiguration:self.configuration path:_path json:_json];
	
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



