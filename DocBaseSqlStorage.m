//
//  DocBaseSqlStorage.m
//  DocBase
//
//  Created by Neil Allain on 3/15/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseSqlStorage.h"
#import "DocBase.h"
#import "DocBaseDateExtensions.h"
#import <JSON/JSON.h>

const NSInteger BRDocBaseErrorSqlite = 1000;

static NSString* const BRDocBaseSqliteDbName = @"docbase_data.db";

typedef int(*BRSqlCallback)(void*,int,char**,char**);

static int BRSelectSingleColumnCallback(void* instance,int columnCount,char** columnValues,char** columnNames);
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
-(NSMutableDictionary*)translateToDictionary:(NSString*)documentData error:(NSError**)error;
-(BRQueryResults*)executeDocumentQuery:(NSString*)query error:(NSError**)error;
-(BRQueryResults*)executeSingleColumnQuery:(NSString*)query error:(NSError**)error;
-(BRQueryResults*)executeQuery:(NSString*)query callback:(BRSqlCallback)callback error:(NSError**)error;
-(BOOL)executeStatement:(NSString*)statement error:(NSError**)error;
-(BOOL)createTable:(NSString*)tableName columns:(NSString*)columns error:(NSError**)error;
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
-(NSMutableDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error
{
	if (![self openDatabase:error]) return nil;
	NSString* query = [NSString stringWithFormat:@"select documentId, data from documents where documentId='%@'", documentId];
	BRQueryResults* results = [self executeDocumentQuery:query error:error];
	if (results && ([results.results count] >= 1)) {
		return [results.results objectAtIndex:0];
	}	
	return nil;
}

-(NSSet*)allDocuments:(NSError**)error
{
	if (![self openDatabase:error]) return nil;
	NSString* query = @"select documentId, data from documents";
	BRQueryResults* results = [self executeDocumentQuery:query error:error];
	return [NSSet setWithArray:results.results];
}

-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error
{
	if (![self openDatabase:error]) return NO;
	NSString* query = [NSString stringWithFormat:@"select documentId, data from documents where documentId='%@'", documentId];
	BRQueryResults* results = [self executeDocumentQuery:query error:error];
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
		// first remove any previous deleted ids
		if (![self executeStatement:
			[NSString stringWithFormat:@"delete from deletedDocuments where documentId='%@'", documentId] 
			error:error]) return NO;
		stmt = [NSString stringWithFormat:@"insert into documents values('%@', '%@')",
			documentId, documentData];
	}
	return [self executeStatement:stmt error:error];
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error
{
	if (![self openDatabase:error]) return NO;
	NSString* stmt = [NSString stringWithFormat:@"delete from documents where documentId='%@'", documentId];
	if (![self executeStatement:stmt error:error]) {
		return NO;
	}
	NSString* dbDate = [date docBaseString];
	stmt = [NSString stringWithFormat:@"insert into deletedDocuments values('%@', datetime('%@'))", documentId, dbDate];
	return [self executeStatement:stmt error:error];
}

-(NSSet*)deletedDocumentIdsSinceDate:(NSDate*)date error:(NSError**)error
{
	NSString* dbDate = [date docBaseString];
	NSString* query = [NSString stringWithFormat:@"select documentId from deletedDocuments where deleteDate >= datetime('%@')", dbDate];
	BRQueryResults* results = [self executeSingleColumnQuery:query error:error];
	if (results == nil) return nil;
	return [NSSet setWithArray:results.results];
}

#pragma mark -
#pragma mark Private implementation


-(BOOL)openDatabase:(NSError**)error
{
	if (_db != NULL) return YES;
	NSString* dbName = [_path stringByAppendingPathComponent:BRDocBaseSqliteDbName];
	int err = sqlite3_open([dbName UTF8String], &_db);
	if (err != SQLITE_OK) {
		if (error) *error = [self errorForDocumentId:nil withSqliteCode:err];
		return NO;
	}
	if (![self createTable:@"documents" columns:@"documentId TEXT PRIMARY KEY, data TEXT" error:error]) {
		return NO;
	}
	if (![self createTable:@"deletedDocuments" columns:@"documentId TEXT, deleteDate DATETIME" error:error]) {
		return NO;
	}
	return YES;
}

-(NSMutableDictionary*)translateToDictionary:(NSString *)documentData error:(NSError**)error
{
	return [_json objectWithString:documentData error:error];
}

-(NSError*)errorForDocumentId:(NSString*)documentId withSqliteCode:(int)sqliteCode
{
	return [[[NSError alloc] initWithDomain:BRDocBaseErrorDomain code:BRDocBaseErrorSqlite userInfo:nil] autorelease];	
}

-(BRQueryResults*)executeDocumentQuery:(NSString*)query error:(NSError**)error
{
	return [self executeQuery:query callback:BRFindDocumentsCallback error:error];
}

-(BRQueryResults*)executeSingleColumnQuery:(NSString*)query error:(NSError**)error
{
	return [self executeQuery:query callback:BRSelectSingleColumnCallback error:error];
}

-(BRQueryResults*)executeQuery:(NSString*)query callback:(BRSqlCallback)callback error:(NSError**)error
{
	BRQueryResults* results = [BRQueryResults queryResultsWithStorage:self error:error];
	int err = sqlite3_exec(
						   _db, 
						   [query UTF8String], 
						   callback,
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

-(BOOL)createTable:(NSString *)tableName columns:(NSString *)columns error:(NSError **)error
{
	NSString* tableQuery = [NSString stringWithFormat:@"select name from sqlite_master where type='table' and name='%@'", tableName];
	BRQueryResults* results = [self executeSingleColumnQuery:tableQuery error:error];
	if (results == nil) return NO;
	if ([results.results count] == 0) {
		NSString* createStatement = [NSString stringWithFormat:@"create table %@ (%@)", tableName, columns];
		return [self executeStatement:createStatement error:error];
	}
	return YES;
}
@end

static int BRSelectSingleColumnCallback(void* instance,int columnCount,char** columnValues,char** columnNames)
{
	BRQueryResults* results = (BRQueryResults*)instance;
	NSString* value = [NSString stringWithUTF8String:columnValues[0]];
	[results.results addObject:value];
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
