//
//  DocBaseDictionaryExtensions.m
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseDictionaryExtensions.h"
#import "DocBaseDateExtensions.h"

@implementation NSMutableDictionary(BRDocBase_DictionaryExtensions)

-(id)initWithDocumentDictionary:(NSMutableDictionary*)dictionary
{
	return [self initWithDictionary:dictionary];
}

-(NSString*)documentId
{
	return [self objectForKey:BRDocIdKey];
}


-(void)setDocumentId:(NSString*)documentId
{
	NSMutableDictionary* mutable = (NSMutableDictionary*)self;
	[mutable setObject:documentId forKey:BRDocIdKey];
}

-(NSDate*)modificationDate
{
	NSString* dateString = [self objectForKey:BRDocModificationDateKey];
	NSDate* date = [NSDate dateWithDocBaseString:dateString];
	//NSLog(@"converted string: %@ to date: %@", dateString, date);
	return date;
	//return [NSDate dateWithDocBaseString:[self objectForKey:BRDocModificationDateKey]];
}

-(void)setModificationDate:(NSDate*)modificationDate
{
	NSString* dateString = [modificationDate docBaseString];
	//NSLog(@"converted date: %@ to string: %@", modificationDate, dateString);
	//[self setObject:[modificationDate docBaseString] forKey:BRDocModificationDateKey];
	[self setObject:dateString forKey:BRDocModificationDateKey];
}

-(NSDictionary*)documentDictionary
{
	return self;
}
@end