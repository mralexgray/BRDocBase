//
//  DocBaseConfigurationTest.m
//  DocBase
//
//  Created by Neil Allain on 3/15/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDocBaseTest.h"
#import "DocBaseBucketStorage.h"


@interface DocBaseConfigurationTest : BRAbstractDocBaseTest {

}

@end

@implementation DocBaseConfigurationTest

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

-(void)testUnknownStorageType
{
	NSDictionary* config = [NSDictionary dictionaryWithObject:@"badtype" forKey:BRDocBaseConfigStorageType];
	BRDocBase* docBase = [self createDocBaseWithConfiguration:config];
	NSError* error;
	BRAssertTrue(![docBase verifyEnvironment:&error]);
	BRAssertNotNil(error);
	BRAssertTrue([error code] == BRDocBaseErrorUnknownStorageType);
	
	[self deleteDocBase];
	error = nil;
	config = [NSDictionary dictionaryWithObject:@"NSDictionary" forKey:BRDocBaseConfigStorageType];
	docBase = [self createDocBaseWithConfiguration:config];
	BRAssertTrue(![docBase verifyEnvironment:&error]);
	BRAssertNotNil(error);
	BRAssertEqual([NSNumber numberWithInt:BRDocBaseErrorUnknownStorageType], [NSNumber numberWithInt:[error code]]);
}

@end
