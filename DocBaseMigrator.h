//
//  DocBaseMigrator.h
//  DocBase
//
//  Created by Neil Allain on 2/6/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BRDocBase;

@interface BRDocBaseMigrator : NSObject {

}

+(id)docBaseMigrator;
-(BRDocBase*)update:(BRDocBase*)docBase toConfiguration:(NSDictionary*)configuration error:(NSError**)error;
@end
