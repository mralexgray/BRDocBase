//
//  AbstractDocBaseFileStorage.h
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SBJSON;

@interface BRAbstractDocBaseFileStorage : NSObject {
	SBJSON* _json;
	NSString* _path;
	NSMutableArray* _deletedDocuments;
}

-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json;

@property (nonatomic, readonly) SBJSON* json;
@property (nonatomic, readonly) NSString* path;

-(NSSet*)deletedDocumentIdsSinceDate:(NSDate*)date error:(NSError**)error;


-(BOOL)deletedDocumentId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error;

-(id)readJsonFile:(NSString*)path error:(NSError**)error;
-(BOOL)writeJson:(id)jsonObject toFile:(NSString*)path error:(NSError**)error;

@end
