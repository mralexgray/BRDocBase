//
//  DocBaseSqlStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/15/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseSqlStorage.h"
#import "DocBase.h"
#import <JSON/JSON.h>

const NSInteger BRDocBaseErrorSqlite = 1000;

static NSString* const BRDocBaseSqliteDbName = @"docbase_data.db";

static int BRCheckDocumentTableCallback(void* instance,int columnCount,char** columnValues,char** columnNames);
static int BRFindDocumentsCallback(void* instance, int columnCount, char** columnValues, char** columnNames);

@interface BRQueryResults : NSObject
{
	NSMutableArray* _results;
	BRDocBaseSqlStorage* _storage;
	NSError** _error;
}
+(id)queryResultsWithStorage:(BRDocBaseSqlStorage*)storage error:(NSError**)error;
-(id)initWithStorage:(BRDocBaseSqlStorage*)storage error:(NSError**)error;

@property (nonatomic, readonly) NSMutableArray* results;
@property (nonatomic, readonly) BRDocBaseSqlStorage* storage;
@property (nonatomic, readonly) NSError** error;
@end

#pragma mark -
#pragma mark Private Interface
@interface BRDocBaseSqlStorage()
-(BOOL)openDatabase:(NSError**)error;
-(NSError*)errorForDocumentId:(NSString*)documentId withSqliteCode:(int)sqliteCode;
-(NSDictionary*)translateToDictionary:(NSString*)documentData error:(NSError**)error;
-(BRQueryResults*)executeQuery:(NSString*)query error:(NSError**)error;
-(BOOL)executeStatement:(NSString*)statement error:(NSError**)error;
@property (nonatomic, assign) BOOL tableVerified;
@end



@implementation BRDocBaseSqlStorage

#pragma mark -
#pragma mark Initialization
-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json
{
	self = [super init];
	_path = [path retain];
	_json = [json retain];
	_db = NULL;
	return self;
}

-(void)dealloc
{
	[_path release], _path = nil;
	[_json release], _json = nil;
	if (_db) {
		sqlite3_close(_db);
		_db = NULL;
	}
	[super dealloc];
}

#pragma mark -
#pragma mark BRDocBaseStorage methods
-(NSDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error
{
	if (![self openDatabase:error]) return nil;
	NSString* query = [NSString stringWithFormat:@"select documentId, data from documents where documentId='%@'", documentId];
	BRQueryResults* results = [self executeQuery:query error:error];
	if (results && ([results.results count] >= 1)) {
		return [results.results objectAtIndex:0];
	}	
	return nil;
}

-(NSSet*)allDocuments:(NSError**)error
{
	if (![self openDatabase:error]) return nil;
	NSString* query = @"select documentId, data from documents";
	BRQueryResults* results = [self executeQuery:query error:error];
	return [NSSet setWithArray:results.results];
}

-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error
{
	if (![self openDatabase:error]) return NO;
	NSString* query = [NSString stringWithFormat:@"select documentId, data from documents where documentId='%@'", documentId];
	BRQueryResults* results = [self executeQuery:query error:error];
	if (results == nil) {
		return NO;
	}
	NSString* documentData = [_json stringWithObject:document error:error];
	if (documentData == nil) {
		return NO;
	}
	NSString* stmt;
	if ([results.results count] >= 1) {
		// update
		stmt = [NSString stringWithFormat:@"update documents set data='%@' where documentId='%@'",
			documentData, documentId];
	} else {
		// insert
		stmt = [NSString stringWithFormat:@"insert into documents values('%@', '%@')",
			documentId, documentData];
	}
	return [self executeStatement:stmt error:error];
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId error:(NSError**)error
{
	if (![self openDatabase:error]) return NO;
	NSString* stmt = [NSString stringWithFormat:@"delete from documents where documentId='%@'", documentId];
	return [self executeStatement:stmt error:error];
}

#pragma mark -
#pragma mark Private implementation

@synthesize tableVerified = _tableVerified;

-(BOOL)openDatabase:(NSError**)error
{
	if (_db != NULL) return YES;
	NSString* dbName = [_path stringByAppendingPathComponent:BRDocBaseSqliteDbName];
	int err = sqlite3_open([dbName UTF8String], &_db);
	if (err != SQLITE_OK) {
		if (error) *error = [self errorForDocumentId:nil withSqliteCode:err];
		return NO;
	}
	err = sqlite3_exec(
		_db, 
		"select name from sqlite_master where type='table' and name='documents'", 
		BRCheckDocumentTableCallback,
		self, 
		NULL);
	if (err != SQLITE_OK) {
		if (error) *error = [self errorForDocumentId:nil withSqliteCode:err];
		return NO;
	}
	if (!self.tableVerified) {
		err = sqlite3_exec(
			_db, 
			"create table documents (documentId TEXT PRIMARY KEY, data TEXT)", 
			NULL,
			NULL, 
			NULL);
		if (err != SQLITE_OK) {
			if (error) *error = [self errorForDocumentId:nil withSqliteCode:err];
			return NO;			
		}
	}
	return YES;
}

-(NSDictionary*)translateToDictionary:(NSString *)documentData error:(NSError**)error
{
	return [_json objectWithString:documentData error:error];
}

-(NSError*)errorForDocumentId:(NSString*)documentId withSqliteCode:(int)sqliteCode
{
	return [[[NSError alloc] initWithDomain:BRDocBaseErrorDomain code:BRDocBaseErrorSqlite userInfo:nil] autorelease];	
}

-(BRQueryResults*)executeQuery:(NSString*)query error:(NSError**)error
{
	BRQueryResults* results = [BRQueryResults queryResultsWithStorage:self error:error];
	int err = sqlite3_exec(
		_db, 
		[query UTF8String], 
		BRFindDocumentsCallback,
		results, 
		NULL);
	if (err != SQLITE_OK) {
		if (error  && (*error == nil)) *error = [self errorForDocumentId:nil withSqliteCode:err];
		return nil;
	}
	return results;
}

-(BOOL)executeStatement:(NSString*)statement error:(NSError**)error
{
	int err = sqlite3_exec(
		_db, 
		[statement UTF8String], 
		NULL,
		NULL, 
		NULL);
	if (err != SQLITE_OK) {
		if (error) *error = [self errorForDocumentId:nil withSqliteCode:err];
		return NO;
	}
	return YES;
}


@end

static int BRCheckDocumentTableCallback(void* instance,int columnCount,char** columnValues,char** columnNames)
{
	BRDocBaseSqlStorage* storage = (BRDocBaseSqlStorage*)instance;
	storage.tableVerified = YES;
	return 0;
}

static int BRFindDocumentsCallback(void* instance, int columnCount, char** columnValues, char** columnNames)
{
	BRQueryResults* results = (BRQueryResults*)instance;
	NSString* documentData = [NSString stringWithUTF8String:columnValues[1]];
	NSDictionary* documentDictionary = [results.storage translateToDictionary:documentData error:results.error];
	if (documentDictionary) {
		[results.results addObject:documentDictionary];
	} else {
		return -1;
	}
	return 0;
}


@implementation BRQueryResults

+(id)queryResultsWithStorage:(BRDocBaseSqlStorage*)storage error:(NSError**)error
{
	return [[[self alloc] initWithStorage:storage error:error] autorelease];
}

-(id)initWithStorage:(BRDocBaseSqlStorage*)storage error:(NSError**)error;
{
	self = [super init];
	_storage = storage;
	_error = error;
	_results = [[NSMutableArray alloc] init];
	return self;
}

-(void)dealloc
{
	[_results release], _results = nil;
	[super dealloc];
}

@synthesize results = _results;
@synthesize storage = _storage;
@synthesize error = _error;
@end
