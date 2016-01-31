//
//  ScarceResource.m
//  MediatorDemo
//
//  Created by Felix Schwarz on 27.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
//

#import "ScarceResource.h"

@implementation ScarceResource

- (BOOL)tryExclusiveLockWithObject:(id)object
{
	@synchronized(self)
	{
		if (!hasExclusiveLock)
		{
			exclusiveLockObject = object;
			hasExclusiveLock = YES;
			
			return (YES);
		}
	}
	
	return (NO);
}

- (BOOL)trySharedLockWithObject:(id)object
{
	@synchronized(self)
	{
		if (!hasExclusiveLock)
		{
			return (YES);
		}
	}
	
	return (NO);
}

- (void)unlockWithObject:(id)object
{
	@synchronized(self)
	{
		if (hasExclusiveLock)
		{
			if (object == exclusiveLockObject)
			{
				hasExclusiveLock = NO;
				exclusiveLockObject = nil;
			}
		}
	}
}

@end
