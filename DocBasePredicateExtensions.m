//
//  DocBasePredicateExtensions.m
//  DocBase
//
//  Created by Neil Allain on 3/29/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBasePredicateExtensions.h"
#import "DocBase.h"

static BOOL BRIsPredicateForKeyPath(NSPredicate* predicate, NSString* keyPath) {
	if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
		NSComparisonPredicate* comparisonPredicate = (NSComparisonPredicate*)predicate;
		NSExpression* leftExpression = [comparisonPredicate leftExpression];
		if ([keyPath isEqualToString:[leftExpression keyPath]]) {
			return YES;
		}
	}
	return NO;
}

@implementation NSPredicate(BRDocBase_NSPredicateExtensions)

+(NSPredicate*)predicateWithDocumentType:(NSString *)documentType
{
	return [NSPredicate predicateWithFormat:@"class == %@", NSClassFromString(documentType)];
}

+(NSPredicate*)predicateWithModificationDateSince:(NSDate*)date
{
	return [NSPredicate predicateWithFormat:@"modificationDate >= %@", date];
}

-(NSComparisonPredicate*)findIndexedPredicateForProperty:(NSString*)property
{
	NSString* keyPath;
	if ([property isEqualToString:BRDocTypeKey]) {
		keyPath = @"class";
	} else if ([property isEqualToString:BRDocModificationDateKey]) {
		keyPath = @"modificationDate";
	} else {
		keyPath = property;
	}
	if (BRIsPredicateForKeyPath(self, keyPath)) {
		return (NSComparisonPredicate*)self;
	} else if ([self isKindOfClass:[NSCompoundPredicate class]]) {
		NSCompoundPredicate* compoundPredicate = (NSCompoundPredicate*)self;
		if ([compoundPredicate compoundPredicateType] == NSAndPredicateType) {
			for (NSPredicate* subpredicate in [compoundPredicate subpredicates]) {
				if (BRIsPredicateForKeyPath(subpredicate, keyPath)) {
					return (NSComparisonPredicate*)subpredicate;
				}
			}
		}
	}
	return nil;
}

@end


