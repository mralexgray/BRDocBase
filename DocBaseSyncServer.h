//
//  DocBaseSyncServer.h
//  DocBaseServer
//
//  Created by Neil Allain on 3/23/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BRDocBaseSyncRequest;
@class BRDocBase;
@class SBJSON;

extern NSString* const BRDocBaseSyncDocumentAddedNotification;
extern NSString* const BRDocBaseSyncDocumentUpdatedNotification;
extern NSString* const BRDocBaseSyncDocumentDeletedNotification;

@interface BRDocBaseSyncServer : NSObject {
	NSSocketPort* _socketPort;
	NSNetService* _netService;
	NSFileHandle* _fileHandle;
	NSString* _serviceType;
	NSString* _serviceName;
	NSMutableSet* _requests;    
	BRDocBase* _docBase;
	SBJSON* _json;
}

-(id)initWithDocBase:(BRDocBase*)docBase;

@property (retain) NSString* serviceType;
@property (retain) NSString* serviceName;

-(void)start;
-(void)stop;

-(void)cancelRequest:(BRDocBaseSyncRequest*)request;
-(void)handleRequest:(BRDocBaseSyncRequest*)request;
@end
