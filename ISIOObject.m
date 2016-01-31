//
//  ISIOObject.m
//
//  Created by Felix Schwarz on 27.10.15.
//  Copyright © 2015 IOSPIRIT GmbH. All rights reserved.
//

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
