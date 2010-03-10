//
//  DocBaseMigrator.h
//  DocBase
//
//  Created by Neil Allain on 2/6/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BRDocBase;
@protocol BRDocument;

@protocol BRDocBaseMigratorDelegate

///  Return an updated document if needed, otherwise return nil for no update
-(id<BRDocument>)updateDocument:(id<BRDocument>)document 
	fromConfiguration:(NSDictionary*)oldConfiguration 
	toConfiguration:(NSDictionary*)newConfiguration;

@end

@interface BRDocBaseMigrator : NSObject {
	id<BRDocBaseMigratorDelegate> _delegate;
}

+(id)docBaseMigrator;

@property (assign, nonatomic) id<BRDocBaseMigratorDelegate> delegate;

-(BRDocBase*)update:(BRDocBase*)docBase toConfiguration:(NSDictionary*)configuration error:(NSError**)error;
@end
