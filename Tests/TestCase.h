//
//  BRTestCase.h
//  TestItUp
//
//  Created by Neil Allain on 10/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define BRAssertEqual(expected, given) [self assert:expected equalTo:given file:__FILE__ line:__LINE__]
#define BRAssertNotEqual(obj1, obj2) [self assert:obj1 notEqualTo:obj2 file:__FILE__ line:__LINE__]
#define BRAssertTrue(result) [self assertTrue:result file:__FILE__ line:__LINE__]
#define BRAssertNotNil(obj) [self assertNotNil:obj file:__FILE__ line:__LINE__]
#define BRAssertNil(obj) [self assertNil:obj file:__FILE__ line:__LINE__]
#define BRFail(message) [self failWithMessage:message file:__FILE__ line:__LINE__]

@interface BRTestCase : NSObject {
}

+(BOOL)isAbstract;

-(void)setup;
-(void)tearDown;


-(void)assert:(id)expected equalTo:(id)result file:(const char*)file line:(int)line;
-(void)assert:(id)expected notEqualTo:(id)result file:(const char*)file line:(int)line;
-(void)assertTrue:(BOOL)result file:(const char*)file line:(int)line;
-(void)assertNotNil:(id)obj file:(const char*)file line:(int)line;
-(void)assertNil:(id)obj file:(const char*)file line:(int)line;

-(void)failWithMessage:(NSString*)message file:(const char*)file line:(int)line;
@end


@interface BRTestFailureException : NSException
{
}

@property (readonly) NSString* file;
@property (readonly) NSNumber* line;

@end

