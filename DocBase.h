//
//  DocBase.h
//  DocBase
//
//  Created by Neil Allain on 12/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* const BRDocIdKey;
extern NSString* const BRDocRevKey;
extern NSString* const BRDocTypeKey;
extern NSString* const BRDocBaseExtension;
extern const NSUInteger BRDocDefaultBucketCount;

extern NSString* const BRDocBaseErrorDomain;
extern const NSInteger BRDocBaseErrorNotFound;

@class SBJSON;

// Document protocol.  Any object that can be considered a document
// should implement this protocol.
@protocol BRDocument<NSObject>
@required
@property (readwrite, copy) NSString* documentId;
-(NSDictionary*)documentDictionary;
-(id)initWithDocumentDictionary:(NSDictionary*)dictionary;
@end

// Dictionaries are valid document objects
@interface NSDictionary(BRDocument_Dictionary)<BRDocument>
@end


@interface BRDocBase : NSObject {
	SBJSON* _json;
	NSString* _path;

	NSUInteger _bucketCount;
	NSMutableDictionary* _documentsInBucket;
}

@property (readonly) NSString* path;

+(NSString*)generateId;
/// Create a DocBase instance with documents stored at the given path
+(id)docBaseWithPath:(NSString*)path;
/// Initialize a DocBase instance with documents stored at the given path
-(id)initWithPath:(NSString*)path;
/// Save the document to the document database returning the id of the saved document.
-(NSString*)saveDocument:(id<BRDocument>)document error:(NSError**)error;
/// Get the document with the given id.
-(id<BRDocument>)documentWithId:(NSString*)documentId error:(NSError**)error;
/// Find documents matching the given predicate
-(NSSet*)findDocumentsUsingPredicate:(NSPredicate*)predicate error:(NSError**)error;
/// Delete the document with the given id.
-(BOOL)deleteDocumentWithId:(NSString*)documentId error:(NSError**)error;
@end
