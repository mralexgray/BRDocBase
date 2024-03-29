//
//  DocBaseBucketStorage.h
//  DocBase
//
//  Created by Neil Allain on 3/14/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DocBaseStorage.h"
#import "AbstractDocBaseFileStorage.h"

// configuration constants
extern const NSUInteger BRDocDefaultBucketCount;
extern NSString* const BRDocBaseConfigBucketCount;

@interface NSString(BRDocBase_String)
-(NSUInteger)documentIdHash;
@end


@interface BRDocBaseBucketStorage : BRAbstractDocBaseFileStorage<BRDocBaseStorage> {
	NSUInteger _bucketCount;
	NSMutableDictionary* _documentsInBucket;
}

@end
