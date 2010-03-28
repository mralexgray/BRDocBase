//
//  DocBaseSyncClient.m
//  DocBaseClient
//
//  Created by Neil Allain on 3/25/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseSyncClient.h"
#import "DocBase.h"
#import "DocBaseDateExtensions.h"

#define HANDLE_ERR(cond, err) if (!(cond) && ![self handleError:err]) return NO

@interface BRDocBaseSyncClient()
-(BOOL)handleError:(NSError*)error;
-(NSMutableDictionary*)convertToDictionary:(NSSet*)documentSet;
-(BOOL)syncLocalDocument:(id<BRDocument>)localDocument withRemoteDocument:(id<BRDocument>)remoteDocument error:(NSError**)error;
-(BOOL)saveToLocal:(id<BRDocument>)document error:(NSError**)error;
-(BOOL)saveToRemote:(id<BRDocument>)document error:(NSError**)error;
-(BOOL)documentModifiedSinceLastSync:(id<BRDocument>)document;
@end

@implementation BRDocBaseSyncClient

@synthesize localDocBase = _localDocBase;
@synthesize remoteDocBase = _remoteDocBase;
@synthesize lastSyncDate = _lastSyncDate;
@synthesize delegate = _delegate;

-(BOOL)syncDocBase:(BRDocBase*)localDocBase 
	withRemote:(BRDocBase*)remoteDocBase 
	lastSyncDate:(NSDate*)lastSyncDate
{
	return [self 
		syncDocBase:localDocBase 
		withRemote:remoteDocBase 
		lastSyncDate:lastSyncDate 
		documentsMatchingPredicate:[NSPredicate predicateWithValue:YES]];
}

-(BOOL)syncDocBase:(BRDocBase*)localDocBase 
	withRemote:(BRDocBase*)remoteDocBase 
	lastSyncDate:(NSDate*)lastSyncDate
	documentsMatchingPredicate:(NSPredicate*)predicate
{
	// we don't need to retain this stuff, this is just so the delegate can have access to them
	_localDocBase = localDocBase;
	_remoteDocBase = remoteDocBase;
	// make sure the date is at the same resolution as doc base dates.
	if (lastSyncDate == nil) {
		lastSyncDate = [NSDate distantPast];
	}
	_lastSyncDate = [NSDate dateWithDocBaseString:[lastSyncDate docBaseString]];
	
	NSError* error = nil;
	
	NSSet* remoteDeletedDocumentIds = [self.remoteDocBase deletedDocumentIdsSinceDate:self.lastSyncDate error:&error];
	HANDLE_ERR(remoteDeletedDocumentIds, error);
	NSSet* localDeletedDocumentIds = [self.localDocBase deletedDocumentIdsSinceDate:self.lastSyncDate error:&error];
	HANDLE_ERR(localDeletedDocumentIds, error);

	// delete documents in local that have been deleted in remote
	for (NSString* remoteDeletedDocId in remoteDeletedDocumentIds) {
		if ([self.localDocBase documentWithId:remoteDeletedDocId error:nil] != nil) {
			HANDLE_ERR([self.localDocBase deleteDocumentWithId:remoteDeletedDocId error:&error], error);
		}
	}
	
	// delete documents in remote that have been deleted in local
	for (NSString* localDeletedDocId in localDeletedDocumentIds) {
		if ([self.remoteDocBase documentWithId:localDeletedDocId error:nil] != nil) {
			HANDLE_ERR([self.remoteDocBase deleteDocumentWithId:localDeletedDocId error:&error], error);
		}
	}
	

	NSSet* remoteDocuments = [self.remoteDocBase findDocumentsUsingPredicate:[NSPredicate predicateWithValue:YES] error:&error];
	HANDLE_ERR(remoteDocuments, error);
	NSSet* localDocuments = [self.localDocBase  findDocumentsUsingPredicate:[NSPredicate predicateWithValue:YES] error:&error];
	HANDLE_ERR(localDocuments, error);
	
	NSMutableDictionary* remoteDocsById = [self convertToDictionary:remoteDocuments];
	NSMutableDictionary* localDocsById = [self convertToDictionary:localDocuments];
	for (id<BRDocument> remoteDoc in [remoteDocsById allValues]) {
		id<BRDocument> localDoc = [localDocsById objectForKey:remoteDoc.documentId];
		if (localDoc) {
			HANDLE_ERR([self syncLocalDocument:localDoc withRemoteDocument:remoteDoc error:&error], error);
			// remove the local doc so we don't deal with it again
			[localDocsById removeObjectForKey:localDoc.documentId];
		} else {
			HANDLE_ERR([self saveToLocal:remoteDoc error:&error], error);
		}
	}
	for (id<BRDocument> localDoc in [localDocsById allValues]) {
		id<BRDocument> remoteDoc = [remoteDocsById objectForKey:localDoc.documentId];
		if (remoteDoc) {
			// this currently won't occur since we're going through all documents
			// rather than just updated ones.
		} else {
			HANDLE_ERR([self saveToRemote:localDoc error:&error], error);
		}
	}
	return YES;
}

 -(BOOL)syncLocalDocument:(id<BRDocument>)localDocument withRemoteDocument:(id<BRDocument>)remoteDocument error:(NSError**)error
{
	BOOL success = YES;
	BOOL localModified = [self documentModifiedSinceLastSync:localDocument];
	BOOL remoteModified = [self documentModifiedSinceLastSync:remoteDocument];
	if (remoteModified && !localModified) {
		success = [self saveToLocal:remoteDocument error:error];
	} else if (localModified && !remoteModified) {
		success = [self saveToRemote:localDocument error:error];
	} else if (localModified && remoteModified) {
		NSDate* localDate = localDocument.modificationDate;
		// since we're checking local date, local will win a tie
		if ([localDate laterDate:remoteDocument.modificationDate] == localDate) {
			success = [self saveToRemote:localDocument error:error];
		} else {
			success = [self saveToLocal:remoteDocument error:error];
		}
	}
	return success;
}

-(NSMutableDictionary*)convertToDictionary:(NSSet*)documentSet
{
	NSMutableDictionary* docsById = [NSMutableDictionary dictionaryWithCapacity:[documentSet count]];
	for(id<BRDocument> document in documentSet) {
		[docsById setObject:document forKey:document.documentId];
	}
	return docsById;
}

-(BOOL)handleError:(NSError *)error
{
	NSLog(@"Error syncing: %@", error);
	return NO;
}

-(BOOL)documentModifiedSinceLastSync:(id<BRDocument>)document
{
	BOOL modified = YES;
	if ([document respondsToSelector:@selector(modificationDate)]) {
		NSDate* modificationDate = document.modificationDate;
		modified = ([modificationDate laterDate:self.lastSyncDate] == modificationDate);
	}
	return modified;
}

-(BOOL)saveToLocal:(id<BRDocument>)document error:(NSError**)error
{
	if ([document respondsToSelector:@selector(isDocumentEdited)]) {
		document.isDocumentEdited = YES;
	}
	return ([_localDocBase saveDocument:document updateModificationDate:NO error:error] != nil);
}

-(BOOL)saveToRemote:(id<BRDocument>)document error:(NSError**)error
{
	if ([document respondsToSelector:@selector(isDocumentEdited)]) {
		document.isDocumentEdited = YES;
	}
	return ([_remoteDocBase saveDocument:document updateModificationDate:NO error:error] != nil);
}

@end
