//
//  ScarceResource.h
//  MediatorDemo
//
//  Created by Felix Schwarz on 27.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ScarceResource : NSObject
{
	BOOL hasExclusiveLock;
	NSObject *exclusiveLockObject;
}

- (BOOL)tryExclusiveLockWithObject:(id)object;
- (BOOL)trySharedLockWithObject:(id)object;

- (void)unlockWithObject:(id)object;

@end
