//
//  DocBaseSyncServerResponse.m
//  DocBaseServer
//
//  Created by Neil Allain on 3/27/10.
//  Copyright 2010 Blue Rope Software. All rights reserved.
//

#import "DocBaseSyncResponse.h"


@implementation BRDocBaseSyncResponse

#pragma mark -
#pragma mark Initialization

+(id)docBaseSyncResponseWithCode:(CFIndex)code body:(id)body
{
	return [[[self alloc] initWithCode:code body:body] autorelease];
}

-(id)initWithCode:(CFIndex)code body:(id)body
{
	self = [super init];
	_code = code;
	_body = [body retain];
	return self;
}

-(void)dealloc
{
	[_body release], _body = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark Properties
@synthesize body = _body;
@synthesize code = _code;

@end
