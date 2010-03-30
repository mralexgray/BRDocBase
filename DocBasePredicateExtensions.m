//
//  DocBasePredicateExtensions.m
//  DocBase
//
//  Created by Neil Allain on 3/29/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBasePredicateExtensions.h"


@implementation NSPredicate(BRDocBase_NSPredicateExtensions)

+(NSPredicate*)predicateWithDocumentType:(NSString *)documentType
{
	return [NSPredicate predicateWithFormat:@"class == %@", NSClassFromString(documentType)];
}

@end
