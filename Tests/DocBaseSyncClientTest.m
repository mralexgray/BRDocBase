//
//  DocBaseSyncClientTest.m
//  DocBase
//
//  Created by Neil Allain on 3/26/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDocBaseTest.h"
#import "DocBaseSyncClient.h"
#import "DocBaseDateExtensions.h"

NSString* const RemoteDocBaseName = @"remote-doc-base";

@interface DocBaseSyncClientTest : BRAbstractDocBaseTest {
	BRDocBase* _local;
	BRDocBase* _remote;
	NSDate* _pastDate;
	NSDate* _nowDate;
	NSDate* _futureDate;
}
-(BRDocBase*)createRemoteDocBase;
-(void)recreateDocBases;
-(BOOL)sync;
-(BOOL)syncWithDate:(NSDate*)date;
-(BOOL)syncWithPredicate:(NSPredicate*)predicate date:(NSDate*)date;
@end

@implementation DocBaseSyncClientTest

-(void)setup
{
	[super setup];
	[self deleteDocBaseWithName:RemoteDocBaseName];
	_local = [[self createDocBase] retain];
	_remote = [[self createRemoteDocBase] retain];
	_pastDate = [[NSDate docBaseDateWithDate:[[NSDate date] dateByAddingTimeInterval:-1.0]] retain];
	_nowDate = [[NSDate docBaseDate] retain];
	_futureDate = [[NSDate docBaseDateWithDate:[[NSDate date] dateByAddingTimeInterval:2.0]] retain];
}

-(void)tearDown
{
	[_local release];
	[_remote release];
	[_pastDate release];
	[_nowDate release];
	[_futureDate release];
	[super tearDown];
}

-(void)testSyncNewDocumentFromRemote
{
	TestDocument* remoteDoc = [TestDocument testDocumentWithName:@"remote" number:12];
	BRAssertNotNil([_remote saveDocument:remoteDoc error:nil]);
	BRAssertTrue([self sync]);
	TestDocument* localDoc = [_local documentWithId:remoteDoc.documentId error:nil];
	BRAssertNotNil(localDoc);
	BRAssertEqual(remoteDoc.name, localDoc.name);
	BRAssertTrue(remoteDoc.number == localDoc.number);
	BRAssertEqual(remoteDoc.modificationDate, localDoc.modificationDate);
}

-(void)testSyncNewDocumentFromLocal
{
	TestDocument* localDoc = [TestDocument testDocumentWithName:@"local" number:12];
	BRAssertNotNil([_local saveDocument:localDoc error:nil]);
	BRAssertTrue([self sync]);
	TestDocument* remoteDoc = [_remote documentWithId:localDoc.documentId error:nil];
	BRAssertNotNil(remoteDoc);
	BRAssertEqual(localDoc.name, remoteDoc.name);
	BRAssertTrue(localDoc.number == remoteDoc.number);
	BRAssertEqual(localDoc.modificationDate, remoteDoc.modificationDate);
}

-(void)testSyncDeletedDocumentFromRemote
{
	TestDocument* sharedDoc = [TestDocument testDocumentWithName:@"shared" number:14];
	NSString* docId = [_remote saveDocument:sharedDoc error:nil];
	BRAssertNotNil(docId);
	BRAssertNotNil([_local saveDocument:sharedDoc error:nil]);
	BRAssertTrue([_remote deleteDocumentWithId:docId error:nil]);
	[self sync];
	BRAssertNil([_local documentWithId:docId error:nil]);
	BRAssertTrue([[_local deletedDocumentIdsSinceDate:nil error:nil] containsObject:docId]);
}

-(void)testSyncDeletedDocumentFromLocal
{
	TestDocument* sharedDoc = [TestDocument testDocumentWithName:@"shared" number:14];
	NSString* docId = [_remote saveDocument:sharedDoc error:nil];
	BRAssertNotNil(docId);
	BRAssertNotNil([_local saveDocument:sharedDoc error:nil]);
	BRAssertTrue([_local deleteDocumentWithId:docId error:nil]);
	[self sync];
	BRAssertNil([_remote documentWithId:docId error:nil]);
	BRAssertTrue([[_remote deletedDocumentIdsSinceDate:nil error:nil] containsObject:docId]);
}

-(void)testSyncUpdatedDocumentFromRemote
{
	TestDocument* sharedDoc = [TestDocument testDocumentWithName:@"shared" number:14];
	sharedDoc.modificationDate = _pastDate;
	NSString* docId = [_remote saveDocument:sharedDoc updateModificationDate:NO error:nil];
	BRAssertNotNil(docId);
	BRAssertNotNil([_local saveDocument:sharedDoc updateModificationDate:NO error:nil]);
	sharedDoc.name = @"updated";
	sharedDoc.number = 15;
	BRAssertNotNil([_remote saveDocument:sharedDoc error:nil]);
	[self recreateDocBases];
	[self syncWithDate:_nowDate];
	TestDocument* updatedDoc = [_local documentWithId:sharedDoc.documentId error:nil];
	BRAssertNotNil(updatedDoc);
	BRAssertEqual(sharedDoc.name, updatedDoc.name);
	BRAssertTrue(sharedDoc.number == updatedDoc.number);
	BRAssertEqual(sharedDoc.modificationDate, updatedDoc.modificationDate);	
}

-(void)testSyncUpdatedDocumentFromLocal
{
	TestDocument* sharedDoc = [TestDocument testDocumentWithName:@"shared" number:14];
	sharedDoc.modificationDate = _pastDate;
	NSString* docId = [_remote saveDocument:sharedDoc updateModificationDate:NO error:nil];
	BRAssertNotNil(docId);
	BRAssertNotNil([_local saveDocument:sharedDoc updateModificationDate:NO error:nil]);
	sharedDoc.name = @"updated";
	sharedDoc.number = 15;
	BRAssertNotNil([_local saveDocument:sharedDoc error:nil]);
	[self recreateDocBases];
	[self syncWithDate:_nowDate];
	TestDocument* updatedDoc = [_remote documentWithId:sharedDoc.documentId error:nil];
	BRAssertNotNil(updatedDoc);
	BRAssertEqual(sharedDoc.name, updatedDoc.name);
	BRAssertTrue(sharedDoc.number == updatedDoc.number);
	BRAssertEqual(sharedDoc.modificationDate, updatedDoc.modificationDate);	
}

-(void)testSyncDocumentLocalUpdatedLater
{
	TestDocument* sharedDoc = [TestDocument testDocumentWithName:@"shared" number:14];
	sharedDoc.modificationDate = _nowDate;
	NSString* docId = [_remote saveDocument:sharedDoc updateModificationDate:NO error:nil];
	BRAssertNotNil(docId);
	sharedDoc.name = @"updated";
	sharedDoc.number = 15;
	sharedDoc.modificationDate = _futureDate;
	BRAssertNotNil([_local saveDocument:sharedDoc updateModificationDate:NO error:nil]);
	[self recreateDocBases];
	[self syncWithDate:_pastDate];
	// remote should have new version
	TestDocument* updatedDoc = [_remote documentWithId:sharedDoc.documentId error:nil];
	BRAssertNotNil(updatedDoc);
	BRAssertEqual(sharedDoc.name, updatedDoc.name);
	BRAssertTrue(sharedDoc.number == updatedDoc.number);
	BRAssertEqual(sharedDoc.modificationDate, updatedDoc.modificationDate);	
}

-(void)testSyncDocumentRemoteUpdatedLater
{
	TestDocument* sharedDoc = [TestDocument testDocumentWithName:@"shared" number:14];
	sharedDoc.modificationDate = _nowDate;
	NSString* docId = [_local saveDocument:sharedDoc updateModificationDate:NO error:nil];
	BRAssertNotNil(docId);
	sharedDoc.name = @"updated";
	sharedDoc.number = 15;
	sharedDoc.modificationDate = _futureDate;
	BRAssertNotNil([_remote saveDocument:sharedDoc updateModificationDate:NO error:nil]);
	[self recreateDocBases];
	[self syncWithDate:_pastDate];
	// local should have new version
	TestDocument* updatedDoc = [_local documentWithId:sharedDoc.documentId error:nil];
	BRAssertNotNil(updatedDoc);
	BRAssertEqual(sharedDoc.name, updatedDoc.name);
	BRAssertTrue(sharedDoc.number == updatedDoc.number);
	BRAssertEqual(sharedDoc.modificationDate, updatedDoc.modificationDate);	
}

-(void)testSyncDocumentsMatchingPredicate
{
	TestDocument* matchingRemoteDoc = [TestDocument testDocumentWithName:@"remote" number:14];
	TestDocument* notMatchingRemoteDoc = [TestDocument testDocumentWithName:@"remote" number:15];
	TestDocument* matchingLocalDoc = [TestDocument testDocumentWithName:@"local" number:14];
	TestDocument* notMatchingLocalDoc = [TestDocument testDocumentWithName:@"local" number:15];
	BRAssertNotNil([_remote saveDocument:matchingRemoteDoc error:nil]);
	BRAssertNotNil([_remote saveDocument:notMatchingRemoteDoc error:nil]);
	BRAssertNotNil([_local saveDocument:matchingLocalDoc error:nil]);
	BRAssertNotNil([_local saveDocument:notMatchingLocalDoc error:nil]);
	NSPredicate* predicate = [NSPredicate predicateWithFormat:@"number = 14"];
	[self syncWithPredicate:predicate date:_pastDate];
	BRAssertNotNil([_remote documentWithId:matchingLocalDoc.documentId error:nil]);
	BRAssertNil([_remote documentWithId:notMatchingLocalDoc.documentId error:nil]);
	BRAssertNotNil([_local documentWithId:matchingRemoteDoc.documentId error:nil]);
	BRAssertNil([_local documentWithId:notMatchingRemoteDoc.documentId error:nil]);
}


#pragma mark -
#pragma mark Helper methods
-(BRDocBase*)createRemoteDocBase
{
	return [self createDocBaseWithName:RemoteDocBaseName];
}

-(BOOL)syncWithDate:(NSDate*)date
{
	if (date) date = [NSDate docBaseDateWithDate:date];
	BRDocBaseSyncClient* sync = [[[BRDocBaseSyncClient alloc] init] autorelease];
	return [sync syncDocBase:_local withRemote:_remote lastSyncDate:date error:nil];
}

-(BOOL)syncWithPredicate:(NSPredicate*)predicate date:(NSDate*)date
{
	BRDocBaseSyncClient* sync = [[[BRDocBaseSyncClient alloc] init] autorelease];
	return [sync syncDocBase:_local withRemote:_remote documentsMatchingPredicate:predicate lastSyncDate:date error:nil];
}

-(BOOL)sync
{
	return [self syncWithDate:nil];
}

-(void)recreateDocBases
{
	[_remote release];
	[_local release];
	_remote = [[self createRemoteDocBase] retain];
	_local = [[self createDocBase] retain];
}
@end
