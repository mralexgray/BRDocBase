//
//  DocBaseSyncServerResponse.h
//  DocBaseServer
//
//  Created by Neil Allain on 3/27/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BRDocBaseSyncResponse : NSObject {
	id _body;
	CFIndex _code;
}

+(id)docBaseSyncResponseWithCode:(CFIndex)code body:(id)body;
-(id)initWithCode:(CFIndex)code body:(id)body;

@property (readonly) id body;
@property (readonly) CFIndex code;

@end
