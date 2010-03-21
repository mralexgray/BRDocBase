//
//  DocBaseDateExtensionsTest.m
//  DocBase
//
//  Created by Neil Allain on 3/21/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TestCase.h"
#import "DocBaseDateExtensions.h"

@interface DocBaseDateExtensionsTest : BRTestCase {

}

@end

@implementation DocBaseDateExtensionsTest

-(void)setup
{
}

-(void)tearDown
{
}

-(void)testDate
{
	NSDate* date = [NSDate date];
	NSString* dateString = [date docBaseString];
	BRAssertNotNil(dateString);
	NSDate* parsedDate = [NSDate dateWithDocBaseString:dateString];
	BRAssertNotNil(parsedDate);
	NSTimeInterval difference = [date timeIntervalSinceDate:parsedDate];
	BRAssertTrue(fabs(difference) < 0.001);
}

@end
