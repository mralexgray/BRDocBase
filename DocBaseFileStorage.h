//
//  DocBaseFileStorage.h
//  DocBase
//
//  Created by Neil Allain on 3/15/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DocBaseStorage.h"

@interface BRDocBaseFileStorage : NSObject<BRDocBaseStorage> {
	SBJSON* _json;
	NSString* _path;
	NSMutableDictionary* _documents;
}

@end
