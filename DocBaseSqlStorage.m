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
#import "DocBasePredicateExtensions.h"
#import <JSON/JSON.h>

NSString* const BRDocBaseConfigIndexes = @"indexes";
NSString* const BRDocBaseConfigIndexName = @"name";
NSString* const BRDocBaseConfigIndexType = @"type"; 


const NSInteger BRDocBaseErrorSqlite = 1000;

static NSString* const BRDocBaseSqliteDbName = @"docbase_data.db";

typedef int(*BRSqlCallback)(void*,int,char**,char**);

static int BRSelectSingleColumnCallback(void* instance,int columnCount,char** columnValues,char** columnNames);
static int BRFindDocumentsCallback(void* instance, int columnCount, char** columnValues, char** columnNames);
static id BRFormatSqlValue(id value);

@interface BRQueryResults : NSObject
{
	NSMutableSet* _results;
	BRDocBaseSqlStorage* _storage;
	NSError** _error;
}
+(id)queryResultsWithStorage:(BRDocBaseSqlStorage*)storage error:(NSError**)error;
-(id)initWithStorage:(BRDocBaseSqlStorage*)storage error:(NSError**)error;

@property (nonatomic, readonly) NSMutableSet* results;
@property (nonatomic, readonly) BRDocBaseSqlStorage* storage;
@property (nonatomic, readonly) NSError** error;
@end

@interface BRDocBaseIndex : NSObject
{
	NSString* _name;
	NSString* _type;
}
+(id)docBaseIndexWithName:(NSString*)name type:(NSString*)type;

@property (nonatomic, retain) NSString* name;
@property (nonatomic, retain) NSString* type;

@end

#pragma mark -
#pragma mark Private Interface
@interface BRDocBaseSqlStorage()
-(BOOL)openDatabase:(NSError**)error;
-(NSError*)errorForDocumentId:(NSString*)documentId withSqliteCode:(int)sqliteCode;
-(NSMutableDictionary*)translateToDictionary:(NSString*)documentData error:(NSError**)error;
-(BOOL)saveValue:(id)value forDocumentId:(NSString*)documentId toTable:(NSString*)table inserted:(BOOL*)inserted error:(NSError**)error;
-(BRQueryResults*)executeDocumentQuery:(NSString*)query error:(NSError**)error;
-(BRQueryResults*)executeSingleColumnQuery:(NSString*)query error:(NSError**)error;
-(BRQueryResults*)executeQuery:(NSString*)query callback:(BRSqlCallback)callback error:(NSError**)error;
-(BOOL)executeStatement:(NSString*)statement error:(NSError**)error;
-(BOOL)createTable:(NSString*)tableName columns:(NSString*)columns created:(BOOL*)created error:(NSError**)error;
-(NSString*)queryForIndex:(BRDocBaseIndex*)index predicate:(NSComparisonPredicate*)predicate;
@end



@implementation BRDocBaseSqlStorage

#pragma mark -
#pragma mark Initialization
-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json
{
	self = [super init];
	_path = [path retain];
	_json = [json retain];
	_indexes = nil;
	NSArray* indexes = [configuration objectForKey:BRDocBaseConfigIndexes];
	if (indexes) {
		NSMutableArray* mutableArray = [[NSMutableArray alloc] init];
		_indexes = mutableArray;
		for (NSDictionary* indexValues in indexes) {
			BRDocBaseIndex* index = [BRDocBaseIndex 
				docBaseIndexWithName:[indexValues objectForKey:BRDocBaseConfigIndexName] 
				type:[indexValues objectForKey:BRDocBaseConfigIndexType]];
			[mutableArray addObject:index];
		}
	}
	_db = NULL;
	return self;
}

-(void)dealloc
{
	[_indexes release], _indexes = nil;
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
		return [results.results anyObject];
	}	
	return nil;
}

-(NSSet*)findDocumentsWithPredicate:(NSPredicate*)predicate error:(NSError**)error
{
	if (![self openDatabase:error]) return nil;
	NSMutableArray* indexSubselects = [NSMutableArray array];
	for (BRDocBaseIndex* index in _indexes) {
		NSComparisonPredicate* indexedPredicate = [predicate findIndexedPredicateForProperty:index.name];
		if (indexedPredicate) {
			NSString* indexSubselect = [self queryForIndex:index predicate:indexedPredicate];
			if (indexSubselect) {
				[indexSubselects addObject:indexSubselect];
			}
		}
	}
	NSString* query = @"select documentId, data from documents";
	if ([indexSubselects count] > 0) {
		NSMutableString* queryBuffer = [NSMutableString stringWithFormat:@"%@ where ", query];
		NSString* join = @"";
		for (NSString* subselect in indexSubselects) {
			[queryBuffer appendFormat:@"%@(documentId in (%@))", join, subselect];
			join = @" and ";
		}
		//NSLog(@"Indexed document query:\n%@", queryBuffer);
		query = queryBuffer;
	}
	BRQueryResults* results = [self executeDocumentQuery:query error:error];
	return results.results;
}

-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error
{
	if (![self openDatabase:error]) return NO;
	NSString* documentData = [_json stringWithObject:document error:error];
	if (documentData == nil) {
		return NO;
	}
	BOOL documentInserted = NO;
	if (![self saveValue:documentData forDocumentId:documentId toTable:@"documents" inserted:&documentInserted error:error]) {
		return NO;
	}
	for (BRDocBaseIndex* index in _indexes) {
		id indexValue = [document objectForKey:index.name];
		if (indexValue) {
			BOOL inserted;
			NSString* indexTable = [NSString stringWithFormat:@"index_%@", index.name];
			if (![self saveValue:indexValue forDocumentId:documentId toTable:indexTable inserted:&inserted error:error]) {
				return NO;
			}
		}
	}
	if (documentInserted) {
		// remove any previous deleted ids
		NSString* stmt = [NSString stringWithFormat:@"delete from deletedDocuments where documentId='%@'", documentId];
		if (![self executeStatement:stmt error:error]) return NO;
	}
	return YES;
}

-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error
{
	if (![self openDatabase:error]) return NO;
	NSString* stmt = [NSString stringWithFormat:@"delete from documents where documentId='%@'", documentId];
	if (![self executeStatement:stmt error:error]) {
		return NO;
	}
	for (BRDocBaseIndex* index in _indexes) {
		stmt = [NSString stringWithFormat:@"delete from index_%@ where documentId='%@'", index.name, documentId];
		if (![self executeStatement:stmt error:error]) {
			return NO;
		}
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
	return results.results;
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
	BOOL tableCreated;
	if (![self createTable:@"documents" columns:@"documentId TEXT PRIMARY KEY, data TEXT" created:&tableCreated error:error]) {
		return NO;
	}
	BOOL applyIndexes = !tableCreated;	// if it's an existing databsae, reindex when needed
	if (![self createTable:@"deletedDocuments" columns:@"documentId TEXT, deleteDate DATETIME" created:&tableCreated error:error]) {
		return NO;
	}
	for (BRDocBaseIndex* index in _indexes) {
		NSString* indexName = [NSString stringWithFormat:@"index_%@", index.name];
		NSString* columns = [NSString stringWithFormat:@"documentId TEXT PRIMARY KEY, data %@", index.type];
		if (![self createTable:indexName columns:columns  created:&tableCreated error:error]) {
			return NO;
		}
		if (tableCreated && applyIndexes) {
			NSLog(@"need to update the indexes here");
		}
	}
	return YES;
}

-(NSMutableDictionary*)translateToDictionary:(NSString *)documentData error:(NSError**)error
{
	return [_json objectWithString:documentData error:error];
}

-(BOOL)saveValue:(id)value forDocumentId:(NSString*)documentId toTable:(NSString*)table inserted:(BOOL*)inserted error:(NSError**)error
{
	value = BRFormatSqlValue(value);
	NSString* query = [NSString stringWithFormat:@"select documentId from %@ where documentId='%@'", table, documentId];
	BRQueryResults* results = [self executeSingleColumnQuery:query error:error];
	if (results == nil) {
		return NO;
	}
	NSString* stmt;
	if ([results.results count] >= 1) {
		// update
		*inserted = NO;
		stmt = [NSString stringWithFormat:@"update %@ set data=%@ where documentId='%@'",
				table, value, documentId];
	} else {
		// insert
		*inserted = YES;
		stmt = [NSString stringWithFormat:@"insert into %@ values('%@', %@)",
				table, documentId, value];
	}
	if (![self executeStatement:stmt error:error]) {
		return NO;
	}
	return YES;
}

-(NSString*)queryForIndex:(BRDocBaseIndex*)index predicate:(NSComparisonPredicate*)predicate
{
	NSString* query = nil;
	NSString* sqlOperator = nil;
	switch ([predicate predicateOperatorType]) {
		case NSLessThanPredicateOperatorType:
			sqlOperator = @"<";
			break;
		case NSLessThanOrEqualToPredicateOperatorType:
			sqlOperator = @"<=";
			break;
		case NSGreaterThanPredicateOperatorType:
			sqlOperator = @">";
			break;
		case NSGreaterThanOrEqualToPredicateOperatorType:
			sqlOperator = @">=";
			break;
		case NSEqualToPredicateOperatorType:
			sqlOperator = @"=";
			break;
		default:
			sqlOperator = nil;
	}
	if (sqlOperator) {
		NSExpression* rhs = [predicate rightExpression];
		if ([rhs expressionType] == NSConstantValueExpressionType) {
			query = [NSString stringWithFormat:@"select documentId from index_%@ where data %@ %@",
				index.name, sqlOperator, BRFormatSqlValue([rhs constantValue])];
		}
	}
	return query;
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

-(BOOL)createTable:(NSString *)tableName columns:(NSString *)columns created:(BOOL*)created error:(NSError **)error
{
	NSString* tableQuery = [NSString stringWithFormat:@"select name from sqlite_master where type='table' and name='%@'", tableName];
	BRQueryResults* results = [self executeSingleColumnQuery:tableQuery error:error];
	if (results == nil) return NO;
	if ([results.results count] == 0) {
		*created = YES;
		NSString* createStatement = [NSString stringWithFormat:@"create table %@ (%@)", tableName, columns];
		return [self executeStatement:createStatement error:error];
	} else {
		*created = NO;
	}
	return YES;
}
@end

#pragma mark -
#pragma mark BRQueryResults implementation

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
	_results = [[NSMutableSet alloc] init];
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


#pragma mark -
#pragma mark BRDocBaseIndex implementation

@implementation BRDocBaseIndex

+(id)docBaseIndexWithName:(NSString*)name type:(NSString*)type
{
	BRDocBaseIndex* index = [[[self alloc] init] autorelease];
	index.name = name;
	index.type = type;
	return index;
}

-(void)dealloc
{
	[_name release], _name = nil;
	[_type release], _type = nil;
	[super dealloc];
}

@synthesize name = _name;
@synthesize type = _type;

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

static id BRFormatSqlValue(id value)
{
	if ([value isKindOfClass:[NSString class]]) {
		NSString* sval = (NSString*)value;
		sval = [sval stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
		value = [NSString stringWithFormat:@"'%@'", sval];
	} else if ([value isKindOfClass:[NSDate class]]) {
		NSDate* dval = (NSDate*)value;
		value = [NSString stringWithFormat:@"'%@'", [dval docBaseString]];
	} else if (![value isKindOfClass:[NSValue class]]) {
		value = [NSString stringWithFormat:@"'%@'", value];
	}
	return value;
}