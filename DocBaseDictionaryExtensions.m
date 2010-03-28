//
//  DocBaseDictionaryExtensions.m
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseDictionaryExtensions.h"
#import "DocBaseDateExtensions.h"


@implementation NSDictionary(BRDocBase_DictionaryExtensions)
-(NSDate*)docBaseModificationDate
{
	NSString* dateString = [self objectForKey:BRDocModificationDateKey];
	if (dateString) {
		return [NSDate dateWithDocBaseString:dateString];
	}
	//NSLog(@"converted string: %@ to date: %@", dateString, date);
	return nil;
	//return [NSDate dateWithDocBaseString:[self objectForKey:BRDocModificationDateKey]];
}

@end

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
	return [self docBaseModificationDate];
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


+(NSMutableDictionary*)dictionaryWithDocument:(id<BRDocument>)document objectsAndKeys:(id)firstObject,...
{
	NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
	[dictionary setObject:document.documentId forKey:BRDocIdKey];
	[dictionary setObject:[[document class] description] forKey:BRDocTypeKey];
	if ([document respondsToSelector:@selector(modificationDate)]) {
		NSString* docBaseDate = [document.modificationDate docBaseString];
		[dictionary setObject:docBaseDate forKey:BRDocModificationDateKey];
	}
	va_list objectsAndKeys;
	va_start(objectsAndKeys, firstObject);
	id obj = firstObject;
	while (obj) {
		id key = va_arg(objectsAndKeys, id);
		[dictionary setObject:obj forKey:key];
		obj = va_arg(objectsAndKeys, id);
	}
	va_end(objectsAndKeys);
	
	return dictionary;
}

@end
