//
//  DocBaseStorage.h
//  DocBase
//
//  Created by Neil Allain on 3/14/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SBJSON;

@protocol BRDocBaseStorage<NSObject>

-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json;

-(NSDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error;
-(NSSet*)allDocuments:(NSError**)error;
-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error;
-(BOOL)deleteDocumentWithId:(NSString*)documentId error:(NSError**)error;
@end
