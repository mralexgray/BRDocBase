//
//  DocBaseDateExtensions.h
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const BRDocBaseModificationDateFormat;

@interface NSDate(BRDocBase_NSDate)

+(NSDateFormatter*)docBaseFormatter;
+(id)dateWithDocBaseString:(NSString*)dateString;
+(id)docBaseDate;
+(id)docBaseDateWithDate:(NSDate*)date;
-(NSString*)docBaseString;

@end
