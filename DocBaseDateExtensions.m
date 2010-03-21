//
//  DocBaseDateExtensions.m
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseDateExtensions.h"
#import <libkern/OSAtomic.h>

NSString* const BRDocBaseDateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS ZZZZ";

static volatile NSDateFormatter* _docBaseDateFormatter;

@implementation NSDate(BRDocBase_NSDate)

+(NSDateFormatter*)docBaseFormatter
{
    if (_docBaseDateFormatter == nil) {
        @synchronized(self) {
            OSMemoryBarrier();
            if (_docBaseDateFormatter == nil) {
                _docBaseDateFormatter = [[NSDateFormatter alloc] init];
				[_docBaseDateFormatter setDateFormat:BRDocBaseDateFormat];
                OSMemoryBarrier();
            }
        }
    }
    return (NSDateFormatter*)_docBaseDateFormatter;
}

+(id)dateWithDocBaseString:(NSString*)dateString
{
	return [[NSDate docBaseFormatter] dateFromString:dateString];
}

-(NSString*)docBaseString
{
	return [[NSDate docBaseFormatter] stringFromDate:self];
}

@end

