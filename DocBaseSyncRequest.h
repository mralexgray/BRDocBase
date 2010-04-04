//
//  DocBaseSyncConnection.h
//  DocBaseServer
//
//  Created by Neil Allain on 3/23/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BRDocBaseSyncServer;

@interface BRDocBaseSyncRequest : NSObject
{
	BRDocBaseSyncServer* _server;
	NSFileHandle* _fileHandle;
	CFHTTPMessageRef _message;
	BOOL _complete;
	NSUInteger _contentLength;
	
	NSURL* _url;
	NSString* _method;
}

-(id)initWithServer:(BRDocBaseSyncServer*)server fileHandle:(NSFileHandle*)fileHandle;

@property (readonly) NSURL* url;
@property (readonly) NSFileHandle* fileHandle;
@property (readonly) NSString* method;
@property (readonly) NSData* body;
@property (readonly) NSDictionary* queryParams;
@end
