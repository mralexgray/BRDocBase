//
//  DocBaseDictionaryExtensions.h
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DOcBase.h"

@interface NSDictionary(BRDocBase_DictionaryExtensions)
-(NSDate*)docBaseModificationDate;
@end

@interface NSMutableDictionary(BRDocBase_DictionaryExtensions)<BRDocument>

/// Helper method to create document dictionaries.
/// This will handle adding the documentId, doc type, and
/// modification date of the document as well as any other
/// values passed.  It is mainly intended to be used for
/// documentDictionary method implementations.
+(NSMutableDictionary*)dictionaryWithDocument:(id<BRDocument>)document objectsAndKeys:(id)firstObject,...;

@end
