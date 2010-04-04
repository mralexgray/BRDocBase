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

// initialize the document database storage.  The path given is the docbase bundle and
// will be already created in the case of local docbase storage.
-(id)initWithConfiguration:(NSDictionary*)configuration path:(NSString*)path json:(SBJSON*)json;

// Find the document with the given id.  If the document is not found, it is fine that
// the error is not set, the error will be set appropriately by caller.  Any other
// error should be set as usual.
-(NSMutableDictionary*)documentWithId:(NSString*)documentId error:(NSError**)error;

// Find documents using the given predicate.  The storage layer is only required to
// return a superset of the documents matching the predicate, since the documents will
// be filtered after they have been converted.  The predicate should be used only
// to minimize the returned dictionaries if the storage has some form of indexing
-(NSSet*)findDocumentsWithPredicate:(NSPredicate*)predicate error:(NSError**)error;

// Save the document to the storage.  The document can simply be serialized and saved, keyed
// to the given id.  It will already have it's id and any other automatic properties properly set.
-(BOOL)saveDocument:(NSDictionary*)document withDocumentId:(NSString*)documentId error:(NSError**)error;

// Delete the document with the given id.  The deleted id should be preserved with the corresponding date
// so it can be retrieved later with deletedDocumentIdsSinceDate:error:
-(BOOL)deleteDocumentWithId:(NSString*)documentId date:(NSDate*)date error:(NSError**)error;

// Return all the ids of all documents that have been deleted on or after the given date.
-(NSSet*)deletedDocumentIdsSinceDate:(NSDate*)date error:(NSError**)error;

@end
