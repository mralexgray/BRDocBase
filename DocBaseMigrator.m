//
//  DocBaseMigrator.m
//  DocBase
//
//  Created by Neil Allain on 2/6/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseMigrator.h"
#import "DocBase.h"

#pragma mark -
#pragma mark Private Interface
@interface BRDocBaseMigrator()
-(NSString*)tempDocBasePath;
-(BOOL)deleteDocBaseAtPath:(NSString*)path error:(NSError**)error;
@end

@implementation BRDocBaseMigrator

#pragma mark -
#pragma mark Initialization

+(id)docBaseMigrator
{
	return [[[self alloc] init] autorelease];
}

#pragma mark -
#pragma mark Public Methods
-(BRDocBase*)update:(BRDocBase *)docBase toConfiguration:(NSDictionary *)configuration error:(NSError **)error
{
	if (![docBase verifyEnvironment:error]) {
		return nil;
	}
	if ([docBase.configuration isEqualToDictionary:configuration]) {
		// configurations already match, no update needed
		return docBase;
	}
	NSLog(@"Updating BRDocBase configuration from:\n%@\nto:\n%@", docBase.configuration, configuration);
	NSString* tempDocBasePath = [self tempDocBasePath];
	if (![self deleteDocBaseAtPath:tempDocBasePath error:error]) {
		return nil;
	}
	BRDocBase* tempDocBase = [BRDocBase docBaseWithPath:tempDocBasePath configuration:configuration];
	NSPredicate* predicate = [NSPredicate predicateWithValue:YES];
	NSSet* allDocs = [docBase findDocumentsUsingPredicate:predicate error:error];
	if (!allDocs) {
		return nil;
	}
	for (id<BRDocument> doc in allDocs) {
		if (![tempDocBase saveDocument:doc error:error]) {
			return nil;
		}
	}
	NSString* tempOldPath = [docBase.path stringByAppendingFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]];
	if (![self deleteDocBaseAtPath:tempOldPath error:error]) {
		return nil;
	}
	if (![[NSFileManager defaultManager] moveItemAtPath:docBase.path toPath:tempOldPath error:error]) {
		return nil;
	}
	if (![[NSFileManager defaultManager] moveItemAtPath:tempDocBase.path toPath:docBase.path error:error]) {
		return nil;
	}
	[self deleteDocBaseAtPath:tempOldPath error:nil];
	[docBase environmentChanged];
	return [BRDocBase docBaseWithPath:docBase.path];
}


#pragma mark -
#pragma mark Private Methods

-(NSString*)tempDocBasePath
{
	int pid = [[NSProcessInfo processInfo] processIdentifier];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"tempDocBase%d.%@", pid, BRDocBaseExtension]];
}

-(BOOL)deleteDocBaseAtPath:(NSString *)path error:(NSError**)error
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
	}	
	return YES;
}
@end
