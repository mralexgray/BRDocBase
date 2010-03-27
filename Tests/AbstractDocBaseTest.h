//
//  AbstractDocBaseTest.h
//  DocBase
//
//  Created by Neil Allain on 2/6/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TestCase.h"
#import "DocBase.h"

extern NSString* const TestDocBaseName;

@interface BRAbstractDocBaseTest : BRTestCase {
	
}

@property (readonly) NSString* docBasePath;

-(BRDocBase*)createDocBase;
-(BRDocBase*)createDocBaseWithConfiguration:(NSDictionary*)configuration;
-(BRDocBase*)createDocBaseWithName:(NSString*)name;
-(void)deleteDocBaseWithName:(NSString*)name;
-(void)deleteDocBase;

@end

@interface TestDocument : NSObject<BRDocument>
{
	NSString* _documentId;
	NSString* _name;
	NSInteger _number;
	NSDate* _modificationDate;
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
