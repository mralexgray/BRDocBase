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

@interface DocBaseTest : BRAbstractDocBaseTest {

}

@end


@implementation DocBaseTest

-(void)testSave
{
	BRDocBase* docBase = [self createDocBase];
	NSDictionary* document = [NSDictionary dictionaryWithObjectsAndKeys:
							  @"testdoc", BRDocIdKey,
							  @"testname", @"name",
							  nil];
	BRAssertEqual(@"testdoc", [docBase saveDocument:document error:nil]);
	docBase = [self createDocBase];
	document = (NSDictionary*)[docBase documentWithId:@"testdoc" error:nil];
	BRAssertEqual(@"testdoc", [document objectForKey:BRDocIdKey]);
	BRAssertEqual(@"testname", [document objectForKey:@"name"]);
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

-(void)testAddImmutableDocumentError
{
	BRDocBase* docBase = [self createDocBase];
	NSDictionary* document = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"testname", @"name",
								 nil];
	@try {
		[docBase saveDocument:document error:nil];
		BRFail(@"exception should be thrown when trying to add an immutable document without an id");
	}
	@catch (NSException * e) {
		if ([e isKindOfClass:[BRTestFailureException class]]) {
			@throw;
		}
	}
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
	BRAssertTrue([docBase deleteDocumentWithId:docId error:nil]);
	BRAssertNil([docBase documentWithId:docId error:nil]);
	
	docBase = [self createDocBase];
	NSError* error = nil;
	BRAssertNil([docBase documentWithId:docId error:&error]);
	BRAssertNotNil(error);
	BRAssertEqual(BRDocBaseErrorDomain, [error domain]);
	BRAssertTrue([error code] == BRDocBaseErrorNotFound);
}

-(void)testFindDocuments
{
	BRDocBase* docBase = [self createDocBase];
	TestDocument* doc1 = [TestDocument testDocumentWithName:@"foo" number:5];
	TestDocument* doc2 = [TestDocument testDocumentWithName:@"bar" number:6];
	[docBase saveDocument:doc1 error:nil];
	[docBase saveDocument:doc2 error:nil];
	NSPredicate* predicate = [NSPredicate predicateWithFormat:@"name == \"foo\""];
	NSSet* found = [docBase findDocumentsUsingPredicate:predicate error:nil];
	BRAssertTrue([found count] == 1);
	BRAssertTrue([found containsObject:doc1]);
	
	predicate = [NSPredicate predicateWithFormat:@"noattr == \"foo\""];
	found = [docBase findDocumentsUsingPredicate:predicate error:nil];
	BRAssertTrue([found count] == 0);
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

-(void)testDocumentIdHash
{
	NSString* test = @"some random string";
	BRAssertTrue([test hash] != [test documentIdHash]);
	NSString* test2 = @"some other random string";
	BRAssertTrue([test documentIdHash] != [test2 documentIdHash]);
}

-(void)testConfiguration
{
	TestDocument* document = [TestDocument testDocumentWithName:@"test" number:5];	
	BRAssertNotNil([BRDocBase defaultConfiguration]);
	
	// test default configuration
	BRDocBase* docBase = [self createDocBase];
	BRAssertNil(docBase.configuration);
	[docBase saveDocument:document error:nil];	// make sure environment is initied
	BRAssertNotNil(docBase.configuration);
	BRAssertTrue([docBase.configuration isEqualToDictionary:[BRDocBase defaultConfiguration]]);
	
	// test custom configuration
	[self deleteDocBase];
	NSDictionary* configuration = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:55], BRDocBaseConfigBucketCount,
		nil];
	docBase = [self createDocBaseWithConfiguration:configuration];
	BRAssertTrue([configuration isEqualToDictionary:docBase.configuration]);
	[docBase saveDocument:document error:nil];	// make sure config is writting out
	docBase = [self createDocBase];
	[docBase documentWithId:document.documentId error:nil];	// make sure environment is inited
	BRAssertTrue([configuration isEqualToDictionary:docBase.configuration]);
	
	// test config mismatch
	docBase = [self createDocBaseWithConfiguration:[BRDocBase defaultConfiguration]];
	NSError* error = nil;
	BRAssertTrue(![docBase documentWithId:document.documentId error:&error]);
	BRAssertNotNil(error);
	BRAssertTrue([error code] == BRDocBaseErrorConfigurationMismatch);
}

@end

