//
//  DocBasePredicateExtensionsTest.m
//  DocBase
//
//  Created by Neil Allain on 3/29/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TestCase.h"
#import "AbstractDocBaseTest.h"
#import "DocBasePredicateExtensions.h"

@interface DocBasePredicateExtensionsTest : BRTestCase {

}

@end

@implementation DocBasePredicateExtensionsTest

-(void)setup
{
}

-(void)tearDown
{
}

-(void)testPredicateWithDocumentType
{
	NSObject* notADocument = [[[NSObject alloc] init] autorelease];
	TestDocument* doc1 = [TestDocument testDocumentWithName:@"name" number:5];
	ChangeTrackingDocument* doc2 = [ChangeTrackingDocument testDocumentWithName:@"another" number:5];
	NSPredicate* predicate = [NSPredicate predicateWithDocumentType:@"TestDocument"];
	BRAssertTrue([predicate evaluateWithObject:doc1]);
	BRAssertTrue(![predicate evaluateWithObject:doc2]);
	BRAssertTrue(![predicate evaluateWithObject:notADocument]);
}

-(void)testPredicateWithModificationDateSince
{
	NSDate* now = [NSDate date];
	NSPredicate* predicate = [NSPredicate predicateWithModificationDateSince:now];
	TestDocument* doc1 = [TestDocument testDocumentWithName:@"name" number:5];
	doc1.modificationDate = [now dateByAddingTimeInterval:-1.0];
	BRAssertTrue(![predicate evaluateWithObject:doc1]);
	doc1.modificationDate = now;
	BRAssertTrue([predicate evaluateWithObject:doc1]);
	doc1.modificationDate = [now dateByAddingTimeInterval:1.0];
	BRAssertTrue([predicate evaluateWithObject:doc1]);
}


-(void)testFindIndexedPredicateForProperty_DocumentType
{
	NSPredicate* docTypePredicate = [NSPredicate predicateWithDocumentType:@"TestDocument"];
	BRAssertEqual(docTypePredicate, [docTypePredicate findIndexedPredicateForProperty:BRDocTypeKey]);
}

-(void)testFindIndexedPredicateForProperty_ModificationDate
{
	NSPredicate* modificationDatePredicate = [NSPredicate predicateWithModificationDateSince:[NSDate date]];
	BRAssertEqual(modificationDatePredicate, [modificationDatePredicate findIndexedPredicateForProperty:BRDocModificationDateKey]);
}

-(void)testFindIndexedPredicateForProperty_CompoundAnd
{
	NSPredicate* aPredicate = [NSPredicate predicateWithDocumentType:@"TestDocument"];
	NSPredicate* anotherPredicate = [NSPredicate predicateWithFormat:@"name == %@", @"myname"];
	NSPredicate* compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:
									  [NSArray arrayWithObjects:anotherPredicate, aPredicate, nil]];
	BRAssertEqual(aPredicate, [compoundPredicate findIndexedPredicateForProperty:BRDocTypeKey]);
	BRAssertEqual(anotherPredicate, [compoundPredicate findIndexedPredicateForProperty:@"name"]);
}

-(void)testFindIndexedPredicateForProperty_CompoundOr
{
	// or predicates cannot be filtered in pieces
	NSPredicate* aPredicate = [NSPredicate predicateWithDocumentType:@"TestDocument"];
	NSPredicate* anotherPredicate = [NSPredicate predicateWithFormat:@"name == %@", @"myname"];
	NSPredicate* compoundPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:
									  [NSArray arrayWithObjects:anotherPredicate, aPredicate, nil]];
	BRAssertNil([compoundPredicate findIndexedPredicateForProperty:BRDocTypeKey]);
	BRAssertNil([compoundPredicate findIndexedPredicateForProperty:@"name"]);
}

@end
