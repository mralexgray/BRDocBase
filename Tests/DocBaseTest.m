//
//  DocBaseTest.m
//  DocBase
//
//  Created by Neil Allain on 12/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDocBaseTest.h"
#import "DocBase.h"
#import "DocBaseDictionaryExtensions.h"
#import "DocBaseDateExtensions.h"
#import "DocBaseBucketStorage.h"
#import "DocBaseFileStorage.h"
#import "DocBaseSqlStorage.h"
#import "DocBasePredicateExtensions.h"

@interface AbstractDocBaseStorageTest : BRAbstractDocBaseTest {

}
-(void)verifyDocBase:(BRDocBase*)docBase predicate:(NSPredicate*)predicate findsDocuments:(id<BRDocument>)firstDocument, ...;
@end


@implementation AbstractDocBaseStorageTest

+(BOOL)isAbstract
{
	return YES;
}

-(void)testSave
{
	BRDocBase* docBase = [self createDocBase];
	NSDate* start = [NSDate dateWithDocBaseString:[[NSDate date] docBaseString]];
	NSMutableDictionary* document = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							  @"testdoc", BRDocIdKey,
							  @"testname", @"name",
							  nil];
	BRAssertEqual(@"testdoc", [docBase saveDocument:document error:nil]);
	docBase = [self createDocBase];
	document = (NSMutableDictionary*)[docBase documentWithId:@"testdoc" error:nil];
	BRAssertEqual(@"testdoc", [document objectForKey:BRDocIdKey]);
	BRAssertEqual(@"testname", [document objectForKey:@"name"]);
	NSDate* modificationDate = document.modificationDate;
	BRAssertNotNil(modificationDate);
	NSDate* finish = [NSDate dateWithDocBaseString:[[NSDate date] docBaseString]];
	BRAssertTrue([modificationDate laterDate:start] == modificationDate);
	BRAssertTrue([modificationDate earlierDate:finish] == modificationDate);
}

-(void)testAddDocumentWihoutId
{
	BRDocBase* docBase = [self createDocBase];
	NSMutableDictionary* document = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									  @"testname", @"name",
									  nil];
	NSString* docId = [docBase saveDocument:document error:nil];
	BRAssertNotNil(docId);
	BRAssertEqual(document, [docBase documentWithId:docId error:nil]);
	BRAssertEqual(docId, [document documentId]);
}

-(void)testGenerateId
{
	NSString* generatedId = [BRDocBase generateId];
	BRAssertNotNil(generatedId);
	NSString* anotherId = [BRDocBase generateId];
	BRAssertNotEqual(generatedId, anotherId);
	//NSLog(@"generatedId: %@", generatedId);
}

-(void)testNonDictionaryDocument
{
	BRDocBase* docBase = [self createDocBase];
	TestDocument* document = [[[TestDocument alloc] init] autorelease];
	document.name = @"myname";
	document.number = 55;
	NSString* docId = [docBase saveDocument:document error:nil];
	BRAssertNotNil(document.documentId);
	BRAssertEqual(docId, document.documentId);
	BRAssertEqual(document, [docBase documentWithId:docId error:nil]);
	docBase = [self createDocBase];
	TestDocument* reread = [docBase documentWithId:docId error:nil];
	BRAssertNotNil(reread);
	BRAssertEqual(document.documentId, reread.documentId);
	BRAssertEqual(document.name, reread.name);
	BRAssertTrue(document.number == reread.number);
}

-(void)testUnknownDocumentType
{
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										@"myname", @"name",
										@"UnknownType", BRDocTypeKey,
										nil];
	BRDocBase* docBase = [self createDocBase];
	NSString* docId = [docBase saveDocument:dictionary error:nil];
	docBase = [self createDocBase];
	NSDictionary* doc = (NSDictionary*)[docBase documentWithId:docId error:nil];
	BRAssertNotNil(doc);
	BRAssertEqual(@"myname", [doc objectForKey:@"name"]);
}

-(void)testHashedDocBase
{
	// create enough docs to pass the bucket count
	BRDocBase* docBase = [self createDocBase];
	NSMutableDictionary* docs = [NSMutableDictionary dictionary];
	for (NSUInteger i = 0; i < BRDocDefaultBucketCount + 1; ++i) {
		NSString* docName = [NSString stringWithFormat:@"doc%d", i];
		NSMutableDictionary* doc = [NSMutableDictionary 
									dictionaryWithObject:docName forKey:@"name"];
		NSString* docId = [docBase saveDocument:doc error:nil];
		[docs setObject:doc forKey:docId];
	}
	
	// now make sure we can get them all back out
	docBase = [self createDocBase];
	[docs enumerateKeysAndObjectsUsingBlock:^(id docId, id doc, BOOL* stop) {
		NSDictionary* foundDoc = (NSDictionary*)[docBase documentWithId:docId error:nil];
		BRAssertNotNil(foundDoc);
		NSDictionary* originalDoc = (NSDictionary*)doc;
		BRAssertEqual([originalDoc objectForKey:@"name"], [foundDoc objectForKey:@"name"]);
	}];
}


-(void)testDeleteDocument
{
	BRDocBase* docBase = [self createDocBase];
	NSMutableDictionary* doc = [NSMutableDictionary dictionaryWithObject:@"myname" forKey:@"name"];
	NSString* docId = [docBase saveDocument:doc error:nil];
	NSDate* beforeDelete = [NSDate date];
	BRAssertTrue([docBase deleteDocumentWithId:docId error:nil]);
	BRAssertNil([docBase documentWithId:docId error:nil]);
	
	docBase = [self createDocBase];
	NSError* error = nil;
	BRAssertNil([docBase documentWithId:docId error:&error]);
	BRAssertNotNil(error);
	BRAssertEqual(BRDocBaseErrorDomain, [error domain]);
	BRAssertTrue([error code] == BRDocBaseErrorNotFound);
	NSSet* deletedDocIds = [docBase deletedDocumentIdsSinceDate:beforeDelete error:nil];
	BRAssertNotNil(deletedDocIds);
	BRAssertTrue(1 == [deletedDocIds count]);
	BRAssertTrue([deletedDocIds containsObject:docId]);
	
	NSDate* afterDelete = [beforeDelete dateByAddingTimeInterval:2.0];
	deletedDocIds = [docBase deletedDocumentIdsSinceDate:afterDelete error:nil];
	BRAssertNotNil(deletedDocIds);
	BRAssertTrue(0 == [deletedDocIds count]);
}

-(void)testDeleteAndAddDocument
{
	NSDate* beforeDelete = [[NSDate date] dateByAddingTimeInterval:-1.0];
	BRDocBase* docBase = [self createDocBase];
	NSMutableDictionary* doc = [NSMutableDictionary dictionaryWithObject:@"myname" forKey:@"name"];
	NSString* docId = [docBase saveDocument:doc error:nil];
	BRAssertTrue([docBase deleteDocumentWithId:docId error:nil]);
	NSSet* deletedDocIds = [docBase deletedDocumentIdsSinceDate:beforeDelete error:nil];
	BRAssertTrue([deletedDocIds containsObject:docId]);
	
	// add the document back
	BRAssertEqual(docId, [docBase saveDocument:doc error:nil]);
	
	deletedDocIds = [docBase deletedDocumentIdsSinceDate:beforeDelete error:nil];
	BRAssertTrue(![deletedDocIds containsObject:docId]);
}

-(void)testFindDocuments
{
	NSDate* nowDate = [NSDate docBaseDate];
	NSDate* pastDate = [nowDate dateByAddingTimeInterval:-1.0];
	NSDate* futureDate = [nowDate dateByAddingTimeInterval:1.0];
	BRDocBase* docBase = [self createDocBase];
	TestDocument* doc1 = [TestDocument testDocumentWithName:@"foo" number:5];
	doc1.modificationDate = pastDate;
	TestDocument* doc2 = [TestDocument testDocumentWithName:@"bar" number:6];
	doc2.modificationDate = nowDate;
	ChangeTrackingDocument* doc3 = [ChangeTrackingDocument testDocumentWithName:@"foo" number:5];
	doc3.modificationDate = futureDate;
	[docBase saveDocument:doc1 updateModificationDate:NO error:nil];
	[docBase saveDocument:doc2 updateModificationDate:NO error:nil];
	[docBase saveDocument:doc3 updateModificationDate:NO error:nil];
	
	docBase = [self createDocBase];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithFormat:@"name == \"foo\""] findsDocuments:doc1, doc3, nil];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithFormat:@"noattr == \"foo\""] findsDocuments:nil];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithDocumentType:@"TestDocument"] findsDocuments:doc1, doc2, nil];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithDocumentType:@"ChangeTrackingDocument"] findsDocuments:doc3, nil];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithModificationDateSince:futureDate] findsDocuments:doc3, nil];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithModificationDateSince:nowDate] findsDocuments:doc2, doc3, nil];
	[self verifyDocBase:docBase predicate:[NSPredicate predicateWithModificationDateSince:pastDate] findsDocuments:doc1, doc2, doc3, nil];
	
	NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:
		[NSPredicate predicateWithModificationDateSince:pastDate],
		[NSPredicate predicateWithDocumentType:@"TestDocument"],
		nil]];
	[self verifyDocBase:docBase predicate:predicate findsDocuments:doc1, doc2, nil];

	predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:
		[NSPredicate predicateWithModificationDateSince:pastDate],
		[NSPredicate predicateWithFormat:@"name == \"foo\""],
		nil]];
	[self verifyDocBase:docBase predicate:predicate findsDocuments:doc1, doc3, nil];
}

-(void)testIsDocumentEdited
{
	// flag not set, new document should not be saved, an error should be returned
	BRDocBase* docBase = [self createDocBase];
	ChangeTrackingDocument* doc = [ChangeTrackingDocument testDocumentWithName:@"foo" number:5];
	doc.isDocumentEdited = NO;
	NSError* error = nil;
	NSString* docId = [docBase saveDocument:doc error:&error];
	BRAssertNil(docId);
	BRAssertNotNil(error);
	BRAssertTrue([error code] == BRDocBaseErrorNewDocumentNotSaved);
	
	// with flag set, new document should be saved, no error should be returned
	doc.isDocumentEdited = YES;
	docId = [docBase saveDocument:doc error:nil];
	BRAssertTrue(!doc.isDocumentEdited);
	docBase = [self createDocBase];
	doc = [docBase documentWithId:docId error:nil];
	BRAssertNotNil(doc);
	
	// without flag set, existing document should not be saved
	doc.name = @"changed";
	docId = [docBase saveDocument:doc error:nil];
	BRAssertEqual(doc.documentId, docId);
	docBase = [self createDocBase];
	doc = [docBase documentWithId:docId error:nil];
	BRAssertEqual(@"foo", doc.name);
	
	// with flag set, existing document should be saved
	doc.name = @"changed";
	doc.isDocumentEdited = YES;
	[docBase saveDocument:doc error:nil];
	BRAssertTrue(!doc.isDocumentEdited);
	docBase = [self createDocBase];
	doc = [docBase documentWithId:docId error:nil];
	BRAssertEqual(@"changed", doc.name);
	
	// when a document is first read, the flag should be forced to NO
	docBase = [self createDocBase];
	doc = [docBase documentWithId:docId error:nil];
	BRAssertTrue(!doc.isDocumentEdited);
}

-(void)verifyDocBase:(BRDocBase*)docBase predicate:(NSPredicate*)predicate findsDocuments:(id<BRDocument>)firstDocument, ...
{
	NSMutableSet* expectedDocuments = [NSMutableSet set];
	va_list documents;
	va_start(documents, firstDocument);
	id<BRDocument> document = firstDocument;
	while (document) {
		[expectedDocuments addObject:document];
		document = va_arg(documents, id<BRDocument>);
	}
	va_end(documents);
	NSSet* foundDocuments = [docBase findDocumentsUsingPredicate:predicate error:nil];
	BRAssertNotNil(foundDocuments);
	BRAssertEqual([NSNumber numberWithInt:[expectedDocuments count]], [NSNumber numberWithInt:[foundDocuments count]]);
	for (id<BRDocument> expectedDocument in expectedDocuments) {
		BOOL found = NO;
		for (id<BRDocument> foundDocument in foundDocuments) {
			if ([foundDocument.documentId isEqualToString:expectedDocument.documentId]) {
				found = YES;
				break;
			}
		}
		if (!found) {
			NSString* message = [NSString stringWithFormat:@"Didn't find document id: %@", expectedDocument.documentId];
			BRFail(message);
		}
	}
}

@end

@interface BRDocBaseBucketStorageTest : AbstractDocBaseStorageTest
{
}

@end

@implementation BRDocBaseBucketStorageTest

+(BOOL)isAbstract
{
	return NO;
}

-(void)testDocumentIdHash
{
	NSString* test = @"some random string";
	BRAssertTrue([test hash] != [test documentIdHash]);
	NSString* test2 = @"some other random string";
	BRAssertTrue([test documentIdHash] != [test2 documentIdHash]);
}

@end

@interface BRDocBaseFileStorageTest : AbstractDocBaseStorageTest
{
}
@end

@implementation BRDocBaseFileStorageTest
+(BOOL)isAbstract
{
	return NO;
}
-(BRDocBase*)createDocBase
{
	NSDictionary* configuration = [NSDictionary 
		dictionaryWithObject:NSStringFromClass([BRDocBaseFileStorage class]) 
		forKey:BRDocBaseConfigStorageType];
	return [BRDocBase docBaseWithPath:self.docBasePath configuration:configuration];
}

@end

@interface BRDocBaseSqlStorageTest : AbstractDocBaseStorageTest
{
}
@end

@implementation BRDocBaseSqlStorageTest
+(BOOL)isAbstract
{
	return NO;
}
-(BRDocBase*)createDocBase
{
	NSArray* indexes = [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			BRDocTypeKey, BRDocBaseConfigIndexName,
			@"TEXT", BRDocBaseConfigIndexType,
			nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			BRDocModificationDateKey, BRDocBaseConfigIndexName,
			@"DATETIME", BRDocBaseConfigIndexType,
		nil],
						nil];
	NSDictionary* configuration = [NSDictionary dictionaryWithObjectsAndKeys:
		NSStringFromClass([BRDocBaseSqlStorage class]), BRDocBaseConfigStorageType,
		indexes, BRDocBaseConfigIndexes,
		nil];
	return [BRDocBase docBaseWithPath:self.docBasePath configuration:configuration];
}

@end
