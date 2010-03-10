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

@interface DocBaseMigratorTest : BRAbstractDocBaseTest<BRDocBaseMigratorDelegate> {

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
	ChangeTrackingDocument* doc = [ChangeTrackingDocument testDocumentWithName:@"george" number:12];
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

-(void)testUpdateWithSameConfiguration
{
	NSDictionary* originalConfig = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:23], BRDocBaseConfigBucketCount,
		nil];
	NSDictionary* newConfig = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:23], BRDocBaseConfigBucketCount,
		nil];
	BRDocBase* docBase = [self createDocBaseWithConfiguration:originalConfig];	
	BRDocBase* updatedDocBase = [[BRDocBaseMigrator docBaseMigrator] update:docBase toConfiguration:newConfig error:nil];
	BRAssertEqual(docBase, updatedDocBase);
}

-(void)testUpdateEmptyDocBase
{
	[self deleteDocBase];
	NSError* error = nil;
	NSDictionary* config = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:23], BRDocBaseConfigBucketCount,
		nil];
	BRDocBase* updatedDocBase = [[BRDocBaseMigrator docBaseMigrator] 
		update:[BRDocBase docBaseWithPath:self.docBasePath]
		toConfiguration:config error:&error];
	if (updatedDocBase == nil) {
		NSLog(@"error description: %@", [error localizedDescription]);
		NSLog(@"error failure reason: %@", [error localizedFailureReason]);
		NSLog(@"error recovery suggestion: %@", [error localizedRecoverySuggestion]);
	}
	BRAssertNotNil(updatedDocBase);
}

-(void)testUpdateDocumentOnMigrate
{
	NSDictionary* originalConfig = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithInt:23], BRDocBaseConfigBucketCount,
									nil];
	NSDictionary* newConfig = [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithInt:23], BRDocBaseConfigBucketCount,
							   [NSNumber numberWithInt:1], @"VersionNumber", nil];
	BRDocBase* docBase = [self createDocBaseWithConfiguration:originalConfig];
	TestDocument* doc = [TestDocument testDocumentWithName:@"updateme" number:12];
	[docBase saveDocument:doc error:nil];
	
	BRDocBaseMigrator* migrator = [BRDocBaseMigrator docBaseMigrator];
	migrator.delegate = self;
	BRDocBase* updatedDocBase = [migrator update:docBase toConfiguration:newConfig error:nil];
	BRAssertNotNil(updatedDocBase);
	TestDocument* foundDoc = [updatedDocBase documentWithId:doc.documentId error:nil];
	BRAssertNotNil(foundDoc);
	BRAssertEqual(@"I updated you", foundDoc.name);
	BRAssertTrue([newConfig isEqualToDictionary:updatedDocBase.configuration]);
}

-(id<BRDocument>)updateDocument:(id<BRDocument>)document 
	fromConfiguration:(NSDictionary *)oldConfiguration 
	toConfiguration:(NSDictionary *)newConfiguration
{
	if ([document isKindOfClass:[TestDocument class]]) {
		TestDocument* td = (TestDocument*)document;
		if ([td.name isEqualToString:@"updateme"]) {
			TestDocument* newDoc = [TestDocument testDocumentWithName:@"I updated you" number:55];
			newDoc.documentId = td.documentId;
			return newDoc;
		}
	}
	return nil;
}

@end
