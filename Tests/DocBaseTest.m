//
//  DocBaseTest.m
//  DocBase
//
//  Created by Neil Allain on 12/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TestCase.h"
#import "DocBase.h"

static NSString* const TestDocBaseName = @"doc_base_test";

@interface DocBaseTest : BRTestCase {

}

@property (readonly) NSString* docBasePath;

-(BRDocBase*)createDocBase;

@end

@interface TestDocument : NSObject<BRDocument>
{
	NSString* _documentId;
	NSString* _name;
	NSInteger _number;
}
@property (copy, readwrite) NSString* documentId;
@property (copy, readwrite) NSString* name;
@property (assign, readwrite) NSInteger number;

+(id)testDocumentWithName:(NSString*)name number:(NSInteger)number;
-(id)initWithName:(NSString*)name number:(NSInteger)number;

@end

@interface ChangeTrackingDocument : TestDocument
{
	BOOL _isDocumentEdited;
}
@end

@implementation DocBaseTest

-(void)setup
{
	// cleanup any old documents
	NSString* fileName = [self.docBasePath stringByAppendingPathExtension:BRDocBaseExtension];
	if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
		NSError* error;
		if (![[NSFileManager defaultManager] removeItemAtPath:fileName error:&error]) {
			NSLog(@"couldn't delete test doc base at: %@", fileName);
			NSLog(@"error: %@", error);
		}
	}
}

-(void)tearDown
{
}

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
}


-(void)testDocumentIdHash
{
	NSString* test = @"some random string";
	BRAssertTrue([test hash] != [test documentIdHash]);
	NSString* test2 = @"some other random string";
	BRAssertTrue([test documentIdHash] != [test2 documentIdHash]);
}

#pragma mark --
#pragma mark Helper methods

-(NSString*)docBasePath
{
	return [NSTemporaryDirectory() stringByAppendingPathComponent:TestDocBaseName];
}

-(BRDocBase*)createDocBase
{
	return [BRDocBase docBaseWithPath:self.docBasePath];
}

@end

@implementation TestDocument

@synthesize documentId = _documentId;
@synthesize name = _name;
@synthesize number = _number;

+(id)testDocumentWithName:(NSString*)name number:(NSInteger)number
{
	return [[[self alloc] initWithName:name number:number] autorelease];
}

-(id)initWithName:(NSString*)name number:(NSInteger)number
{
	self = [self init];
	_name = [name copy];
	_number = _number;
	return self;
}

-(id)initWithDocumentDictionary:(NSDictionary *)dictionary
{
	self = [super init];
	_documentId = [[dictionary objectForKey:BRDocIdKey] copy];
	_name = [[dictionary objectForKey:@"name"] copy];
	_number = [[dictionary objectForKey:@"number"] intValue];
	return self;
}


-(NSDictionary*)documentDictionary
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			self.documentId, BRDocIdKey,
			self.name, @"name",
			[NSNumber numberWithInt:self.number], @"number",
			nil];
}

@end

@implementation ChangeTrackingDocument

-(id)init
{
	_isDocumentEdited = NO;
	return self;
}

@synthesize isDocumentEdited = _isDocumentEdited;

@end