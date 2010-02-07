//
//  DocBaseMigratorTest.m
//  DocBase
//
//  Created by Neil Allain on 2/6/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDocBaseTest.h"
#import "DocBaseMigrator.h"

@interface DocBaseMigratorTest : BRAbstractDocBaseTest {

}

@end

@implementation DocBaseMigratorTest

-(void)testUpdateConfiguration
{
	NSDictionary* originalConfig = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:23], BRDocBaseConfigBucketCount,
		nil];
	NSDictionary* newConfig = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:31], BRDocBaseConfigBucketCount,
		nil];
	BRDocBase* docBase = [self createDocBaseWithConfiguration:originalConfig];
	TestDocument* doc = [TestDocument testDocumentWithName:@"george" number:12];
	[docBase saveDocument:doc error:nil];
	
	BRDocBase* updatedDocBase = [[BRDocBaseMigrator docBaseMigrator] update:docBase toConfiguration:newConfig error:nil];
	BRAssertNotNil(updatedDocBase);
	TestDocument* foundDoc = [updatedDocBase documentWithId:doc.documentId error:nil];
	BRAssertNotNil(foundDoc);
	BRAssertEqual(doc.name, foundDoc.name);
	BRAssertTrue([newConfig isEqualToDictionary:updatedDocBase.configuration]);
	
	// original docbase should be invalid
	NSError* error = nil;
	BRAssertTrue(![docBase documentWithId:doc.documentId error:&error]);
	BRAssertTrue([error code] == BRDocBaseErrorConfigurationMismatch);
}

@end
