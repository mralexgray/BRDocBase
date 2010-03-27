//
//  DocBaseSyncClient.h
//  DocBaseClient
//
//  Created by Neil Allain on 3/25/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum BRDocBaseSyncConflictResolution {
	BRDocBaseSyncConflictRemoteWins,
	BRDocBaseSyncConflictLocalWins,
} BRDocBaseSyncConflictResolution;

@protocol BRDocument;
@class BRDocBase;
@class BRDocBaseSyncClient;

@protocol BRDocBaseSyncClientDelegate
@optional
-(void)sync:(BRDocBaseSyncClient*)syncClient addingLocalDocument:(id<BRDocument>)document;
-(void)sync:(BRDocBaseSyncClient*)syncClient deletingLocalDocument:(id<BRDocument>)document;
-(void)sync:(BRDocBaseSyncClient*)syncClient updatingLocalDocument:(id<BRDocument>)document withRemoteDocument:(id<BRDocument>)remoteDocument;

-(void)sync:(BRDocBaseSyncClient*)syncClient addingRemoteDocument:(id<BRDocument>)document;
-(void)sync:(BRDocBaseSyncClient*)syncClient deletingRemoteDocument:(id<BRDocument>)document;
-(void)sync:(BRDocBaseSyncClient*)syncClient updatingRemoteDocument:(id<BRDocument>)document withLocalDocument:(id<BRDocument>)remoteDocument;

-(BRDocBaseSyncConflictResolution)sync:(BRDocBaseSyncClient*)syncClient 
	conflictingLocalDocument:(id<BRDocument>)localDocument 
	withRemoteDocument:(id<BRDocument>)remoteDocument;
@end


@interface BRDocBaseSyncClient : NSObject {
	BRDocBase* _localDocBase;
	BRDocBase* _remoteDocBase;
	NSDate* _lastSyncDate;
	id<BRDocBaseSyncClientDelegate> _delegate;
}

@property (readonly) BRDocBase* localDocBase;
@property (readonly) BRDocBase* remoteDocBase;
@property (readonly) NSDate* lastSyncDate;
@property (assign) id<BRDocBaseSyncClientDelegate> delegate;

-(BOOL)syncDocBase:(BRDocBase*)localDocBase 
	withRemote:(BRDocBase*)remoteDocBase 
	lastSyncDate:(NSDate*)lastSyncDate;
@end
