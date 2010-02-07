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

extern NSString* const BRDocBaseConfigBucketCount;

extern NSString* const BRDocBaseErrorDomain;
extern const NSInteger BRDocBaseErrorNotFound;
extern const NSInteger BRDocBaseErrorNewDocumentNotSaved;
extern const NSInteger BRDocBaseErrorConfigurationMismatch;

@class SBJSON;

@interface NSString(BRDocBase_String)
-(NSUInteger)documentIdHash;
@end

// Document protocol.  Any object that can be considered a document
// should implement this protocol.
@protocol BRDocument<NSObject>
@required
@property (readwrite, copy) NSString* documentId;
-(NSDictionary*)documentDictionary;
-(id)initWithDocumentDictionary:(NSDictionary*)dictionary;
@optional

// If implemented, documents will only be saved if they have changes.
// The flag will be cleared once the document has been saved.
// This flag will be ignored if the document was not originally retrieved
// from the document database or has not been saved previously.
@property (readwrite, assign) BOOL isDocumentEdited;

@end

// Dictionaries are valid document objects
@interface NSDictionary(BRDocument_Dictionary)<BRDocument>
@end


@interface BRDocBase : NSObject {
	SBJSON* _json;
	NSString* _path;

	NSDictionary* _configuration;
	NSUInteger _bucketCount;
	NSMutableDictionary* _documentsInBucket;
	BOOL _environmentVerified;
}

@property (readonly) NSString* path;
@property (readonly) NSDictionary* configuration;

+(NSString*)generateId;
+(NSDictionary*)defaultConfiguration;

/// Create a DocBase instance with documents stored at the given path
+(id)docBaseWithPath:(NSString*)path;
/// Create a DocBase instance with documents stored at the given path and configuration
+(id)docBaseWithPath:(NSString*)path configuration:(NSDictionary*)configuration;
/// Initialize a DocBase instance with documents stored at the given path
-(id)initWithPath:(NSString*)path;
/// Initialize a DocBase instance with documents stored at the given path and configuration
-(id)initWithPath:(NSString*)path configuration:(NSDictionary*)configuration;
/// Save the document to the document database returning the id of the saved document.
-(NSString*)saveDocument:(id<BRDocument>)document error:(NSError**)error;
/// Get the document with the given id.
-(id<BRDocument>)documentWithId:(NSString*)documentId error:(NSError**)error;
/// Find documents matching the given predicate
-(NSSet*)findDocumentsUsingPredicate:(NSPredicate*)predicate error:(NSError**)error;
/// Delete the document with the given id.
-(BOOL)deleteDocumentWithId:(NSString*)documentId error:(NSError**)error;
/// Finish any lazy initialization to ensure the doc base is usable
-(BOOL)verifyEnvironment:(NSError**)error;
/// Inform the docbase that it should reverify it's configuration
-(void)environmentChanged;
@end
