//
//  DocBaseRemoteStorage.h
//  DocBase
//
//  Created by Neil Allain on 3/25/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DocBaseStorage.h"

@interface BRDocBaseRemoteStorage : NSObject<BRDocBaseStorage> {
	NSString* _path;
	SBJSON* _json;
}

@end
