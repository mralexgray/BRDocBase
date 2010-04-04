//
//  DocBaseSqlStorage.h
//  DocBase
//
//  Created by Neil Allain on 3/15/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DocBaseStorage.h"
#import <sqlite3.h>

extern NSString* const BRDocBaseConfigIndexes;
extern NSString* const BRDocBaseConfigIndexName;
extern NSString* const BRDocBaseConfigIndexType; 

extern const NSInteger BRDocBaseErrorSqlite;

@interface BRDocBaseSqlStorage : NSObject<BRDocBaseStorage> {
	NSString* _path;
	SBJSON* _json;
	sqlite3* _db;
	NSArray* _indexes;
}

@end
