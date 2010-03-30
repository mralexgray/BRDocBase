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
	
	NSLog(@"predicate format: %@", [predicate predicateFormat]);
}

@end
