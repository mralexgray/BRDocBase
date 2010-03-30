//
//  DocBasePredicateExtensions.h
//  DocBase
//
//  Created by Neil Allain on 3/29/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSPredicate(BRDocBase_NSPredicateExtensions)
+(NSPredicate*)predicateWithDocumentType:(NSString*)documentType;
@end
