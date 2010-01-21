//
//  BRTestCase.m
//  TestItUp
//
//  Created by Neil Allain on 10/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TestCase.h"


@implementation BRTestCase

-(void)setup
{
}

-(void)tearDown
{
}

-(void)assert:(id)expected equalTo:(id)result file:(const char*)file line:(int)line
{
	id<NSObject> expectedObj = expected;
	id<NSObject> resultObj = result;
	if (![expectedObj isEqual:resultObj]) {
		NSString* message = [NSString stringWithFormat:@"results not equal. expected: %@, but was: %@", expectedObj, resultObj];
		[self failWithMessage:message file:file line:line];
	}
}

-(void)assert:(id)expected notEqualTo:(id)result file:(const char*)file line:(int)line
{
	id<NSObject> expectedObj = expected;
	id<NSObject> resultObj = result;
	if ([expectedObj isEqual:resultObj]) {		
		NSString* message = [NSString stringWithFormat:@"results should not be equal to: %@", expectedObj];
		[self failWithMessage:message file:file line:line];
	}
}

-(void)assertTrue:(BOOL)result file:(const char*)file line:(int)line
{
	if (!result) [self failWithMessage:@"result not true" file:file line:line];
}

-(void)assertNotNil:(id)obj file:(const char*)file line:(int)line
{
	if (obj == nil) [self failWithMessage:@"object is nil" file:file line:line];
}

-(void)assertNil:(id)obj file:(const char*)file line:(int)line
{
	if (obj != nil) [self failWithMessage:@"object is not nil" file:file line:line];
}

-(void)failWithMessage:(NSString*)message file:(const char*)file line:(int)line
{
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSString stringWithUTF8String:file], @"file",
							  [NSNumber numberWithInt:line], @"line", nil];
	[[BRTestFailureException exceptionWithName:@"BRTestFailureException" reason:message userInfo:userInfo] raise];
}


@end


@implementation BRTestFailureException

-(NSString*)file
{
	return [[self userInfo] objectForKey:@"file"];
}

-(NSNumber*)line
{
	return [[self userInfo] objectForKey:@"line"];
}

@end

