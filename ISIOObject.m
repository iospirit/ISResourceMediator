//
//  ISIOObject.m
//
//  Created by Felix Schwarz on 27.10.15.
//  Copyright © 2015 IOSPIRIT GmbH. All rights reserved.
//
/*
Copyright (c) 2016 IOSPIRIT GmbH (https://www.iospirit.com/)
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list
  of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or other
  materials provided with the distribution.

* Neither the name of IOSPIRIT GmbH nor the names of its contributors may be used to
  endorse or promote products derived from this software without specific prior
  written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
*/

#import "ISIOObject.h"

@implementation ISIOObject

@synthesize ioObject;
@synthesize uniqueID;

#pragma mark - Init & Dealloc
+ (instancetype)withIOObject:(io_object_t)object
{
	return ([[[self alloc] initWithIOObject:object] autorelease]);
}

- (instancetype)initWithIOObject:(io_object_t)anIOObject
{
	if ((self = [self init]) != nil)
	{
		UInt64 aUniqueID = 0;
		kern_return_t kernReturn;
		
		self.ioObject = anIOObject;

		if ((kernReturn = IORegistryEntryGetRegistryEntryID(anIOObject, &aUniqueID)) == kIOReturnSuccess)
		{
			self.uniqueID = aUniqueID;
		}
	}
	
	return (self);
}

- (void)dealloc
{
	self.ioObject = 0;

	[super dealloc];
}

#pragma mark - Retain & release IOObject
- (void)setIoObject:(io_object_t)newIOObject
{
	if (newIOObject != 0)
	{
		IOObjectRetain(newIOObject);
	}

	if (ioObject != 0)
	{
		IOObjectRelease(ioObject);
	}
	
	ioObject = newIOObject;
}

- (io_object_t)IOObject
{
	return (ioObject);
}

#pragma mark -- Comparison --
- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[ISIOObject class]])
	{
		if ((((ISIOObject *)object).uniqueID == uniqueID) || IOObjectIsEqualTo(((ISIOObject *)object).ioObject, ioObject))
		{
			return(YES);
		}
	}
	
	return (NO);
}

- (NSUInteger)hash
{
	return((NSUInteger)uniqueID);
}

- (id)copyWithZone:(NSZone *)zone
{
	ISIOObject *newObject = [[ISIOObject alloc] init];
	
	newObject.ioObject = ioObject;
	newObject.uniqueID = uniqueID;
	
	return (newObject);
}

@end
