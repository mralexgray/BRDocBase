//
//  AbstractDocBaseTest.m
//  DocBase
//
//  Created by Neil Allain on 2/6/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "AbstractDocBaseTest.h"
#import "TestCase.h"

NSString* const TestDocBaseName = @"doc_base_test";

@implementation BRAbstractDocBaseTest : BRTestCase

-(void)setup
{
	// cleanup any old documents
	[self deleteDocBase];
}

-(void)tearDown
{
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

-(BRDocBase*)createDocBaseWithConfiguration:(NSDictionary*)configuration
{
	return [BRDocBase docBaseWithPath:self.docBasePath configuration:configuration];
}

-(void)deleteDocBase
{
	NSString* fileName = [self.docBasePath stringByAppendingPathExtension:BRDocBaseExtension];
	if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
		NSError* error;
		if (![[NSFileManager defaultManager] removeItemAtPath:fileName error:&error]) {
			NSLog(@"couldn't delete test doc base at: %@", fileName);
			NSLog(@"error: %@", error);
		}
	}
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

-(id)initWithDocumentDictionary:(NSMutableDictionary *)dictionary
{
	self = [self init];
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
	_isDocumentEdited = YES;
	return self;
}

@synthesize isDocumentEdited = _isDocumentEdited;

@end