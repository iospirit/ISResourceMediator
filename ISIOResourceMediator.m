//
//  ISIOResourceMediator.m
//
//  Created by Felix Schwarz on 28.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
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

#import "ISIOResourceMediator.h"
#import "ISIOObject.h"

static void ISIOResourceMediatorDeviceMatchedHandler(void *refcon, io_iterator_t iterator);

static void ISIOResourceMediatorBusyInterestChangeHandler(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument);

@interface ISIOResourceTrackedDevice : ISIOObject
{
	io_object_t busyInterestNotification;

	NSMutableSet *childObjects;
	
	ISIOResourceMediator *resourceMediator;
}

@property(assign) ISIOResourceMediator *resourceMediator;

- (void)installInterestNotificationWithNotificationPort:(IONotificationPortRef)notificationPort;
- (void)updateChildObjects;

@end

@interface ISIOResourceMediator ()

- (void)_handleDeviceMatched:(io_iterator_t)iterator;
- (void)_handleDeviceTerminated:(ISIOResourceTrackedDevice *)trackedDevice;
- (void)_handleUserClientMatched:(ISIOObject *)userClientObj;
- (void)_handleUserClientTerminated:(ISIOObject *)userClientObj;

@end

@implementation ISIOResourceTrackedDevice

@synthesize resourceMediator;

- (void)dealloc
{
	if (busyInterestNotification != 0)
	{
		IOObjectRelease(busyInterestNotification);
		busyInterestNotification = 0;
	}
	
	[childObjects release];
	childObjects = nil;
	
	[super dealloc];
}

- (void)installInterestNotificationWithNotificationPort:(IONotificationPortRef)notificationPort
{
	kern_return_t kernRet = kIOReturnSuccess;

	if (busyInterestNotification != 0)
	{
		return;
	}
	
	if ((kernRet = IOServiceAddInterestNotification(notificationPort, self.ioObject, kIOGeneralInterest, ISIOResourceMediatorBusyInterestChangeHandler, self, &busyInterestNotification)) == kIOReturnSuccess)
	{
		[self updateChildObjects];
	}
}

- (void)updateChildObjects
{
	@synchronized(self)
	{
		io_iterator_t childIterator;
		kern_return_t kernRet;
	
		if (childObjects == nil)
		{
			childObjects = [NSMutableSet new];
		}
		
		if ((kernRet = IORegistryEntryGetChildIterator(self.ioObject, kIOServicePlane, &childIterator)) == kIOReturnSuccess)
		{
			io_object_t childIOObject;
			NSMutableSet *newChildObjects;
			
			if ((newChildObjects = [NSMutableSet new]) != nil)
			{
				NSMutableSet *newChildren=nil, *removedChildren=nil;
				
				while ((childIOObject = IOIteratorNext(childIterator)) != 0)
				{
					ISIOObject *childObj;
					
					if ((childObj = [ISIOObject withIOObject:childIOObject]) != nil)
					{
						[newChildObjects addObject:childObj];
					}
				}
				
				newChildren = [NSMutableSet setWithSet:newChildObjects];
				[newChildren minusSet:childObjects];
				
				if ([newChildren count] > 0)
				{
					for (ISIOObject *newChild in newChildren)
					{
						[resourceMediator _handleUserClientMatched:newChild];
					}
				}

				removedChildren = [NSMutableSet setWithSet:childObjects];
				[removedChildren minusSet:newChildObjects];

				if ([removedChildren count] > 0)
				{
					for (ISIOObject *removedChild in removedChildren)
					{
						[resourceMediator _handleUserClientTerminated:removedChild];
					}
				}
				
				// NSLog(@"New objects: %@ Removed objects: %@", newChildren, removedChildren);

				[childObjects release];
				childObjects = newChildObjects;
			}
			
			IOObjectRelease(childIterator);
		}
	}
}

- (void)_handleService:(io_service_t)service messageType:(uint32_t)messageType messageArgument:(void *)messageArgument
{
	switch(messageType)
	{
		case kIOMessageServiceIsTerminated:
			@synchronized(self)
			{
				for (ISIOObject *ioObj in childObjects)
				{
					[resourceMediator _handleUserClientTerminated:ioObj];
				}
			}
			[resourceMediator _handleDeviceTerminated:self];
		break;
		
		case kIOMessageServiceIsRequestingClose:
		case kIOMessageServiceIsAttemptingOpen:
		case kIOMessageServiceWasClosed:
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self updateChildObjects];
			});
		break;
		
		default:
			// NSLog(@"MSG TYPE %x => %d", messageType, (int)messageArgument);
		break;
	}
}

@end

static void ISIOResourceMediatorBusyInterestChangeHandler(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument)
{
	ISIOResourceTrackedDevice *trackedDevice = (ISIOResourceTrackedDevice *)refcon;
	
	[trackedDevice _handleService:service messageType:messageType messageArgument:messageArgument];
}

@implementation ISIOResourceMediator

@synthesize ioDelegate;

#pragma mark - Init & Dealloc
- (instancetype)initMediatorForResourceWithIdentifier:(NSString *)aResourceIdentifier deviceClassName:(NSString *)aDeviceClassName userClientClassName:(NSString *)aUserClientClassName delegate:(NSObject<ISIOResourceMediatorDelegate> *)aDelegate
{
	if ((self = [self initMediatorForResourceWithIdentifier:aResourceIdentifier delegate:aDelegate]) != nil)
	{
		deviceClassName = [aDeviceClassName retain];
		userClientClassName = [aUserClientClassName retain];
		
		trackedDevices = [NSMutableArray new];
	}
	
	return (self);
}

- (void)dealloc
{
	[self stopObserving];

	[deviceClassName release];
	deviceClassName = nil;

	[userClientClassName release];
	userClientClassName = nil;
	
	[trackedDevices release];
	trackedDevices = nil;

	[super dealloc];
}

#pragma mark - Start/Stop
-(void)setActive:(BOOL)newActive
{
	if (active != newActive)
	{
		[super setActive:newActive];
		
		if (newActive)
		{
			[self startObserving];
		}
		else
		{
			[self stopObserving];
		}
	}
}

#pragma mark - IOKit observing
- (void)startObserving
{
	if (notificationPortRef != NULL)
	{
		return;
	}

	if ((notificationPortRef = IONotificationPortCreate(kIOMasterPortDefault)) != NULL)
	{
		kern_return_t kernResult;

		if ((notificationRunLoopSource = IONotificationPortGetRunLoopSource(notificationPortRef)) != NULL)
		{
			CFRunLoopAddSource(	CFRunLoopGetCurrent(),
						notificationRunLoopSource,
						kCFRunLoopCommonModes);
		}
	
		// Watch existing and new services of deviceClass, including termination
		if (deviceClassName != nil)
		{
			if ((kernResult = IOServiceAddMatchingNotification(notificationPortRef,  kIOMatchedNotification,    IOServiceMatching([deviceClassName UTF8String]), ISIOResourceMediatorDeviceMatchedHandler,    (void *)self, &deviceMatchIterator)) == kIOReturnSuccess)
			{
				[self _handleDeviceMatched:deviceMatchIterator];
			}
		}
	}
}

- (void)stopObserving
{
	if (deviceMatchIterator != 0)
	{
		IOObjectRelease((io_object_t) deviceMatchIterator);
		deviceMatchIterator = 0;
	}

	if (notificationRunLoopSource != NULL)
	{
		CFRunLoopSourceInvalidate(notificationRunLoopSource);
		notificationRunLoopSource = NULL;
	}

	if (notificationPortRef != NULL)
	{
		IONotificationPortDestroy(notificationPortRef);
		notificationPortRef = NULL;
	}
}

#pragma mark - IOKit callback handling
- (void)_handleDeviceMatched:(io_iterator_t)iterator
{
	io_object_t matchingService = 0;

	while ((matchingService = IOIteratorNext(iterator)) != 0)
	{
		ISIOResourceTrackedDevice *deviceObj = nil;

		if ((deviceObj = [[ISIOResourceTrackedDevice alloc] initWithIOObject:matchingService]) != nil)
		{
			BOOL track = YES;
			
			if ((ioDelegate != nil) && ([ioDelegate respondsToSelector:@selector(resourceMediator:trackDevice:)]))
			{
				track = [ioDelegate resourceMediator:self trackDevice:deviceObj];
			}
		
			if (track)
			{
				@synchronized(self)
				{
					deviceObj.resourceMediator = self;
					[deviceObj installInterestNotificationWithNotificationPort:notificationPortRef];

					[trackedDevices addObject:deviceObj];
				}
			}
			
			[deviceObj release];
		}
	
		IOObjectRelease(matchingService);
	};
}

- (void)_handleDeviceTerminated:(ISIOResourceTrackedDevice *)trackedDevice
{
	@synchronized(self)
	{
		trackedDevice.resourceMediator = nil;
		[trackedDevices removeObject:trackedDevice];
	}
}

- (void)_handleUserClientMatched:(ISIOObject *)userClientObj
{
	if (userClientObj != nil)
	{
		BOOL track = YES;
		NSString *pidLine = nil, *appName = nil;
		pid_t userClientPid = 0;
		
		if ((pidLine = (NSString *)IORegistryEntryCreateCFProperty(userClientObj.ioObject, (CFStringRef)@"IOUserClientCreator", kCFAllocatorDefault, 0)) != nil)
		{
			NSRange endRange;
			
			endRange = [pidLine rangeOfString:@", "];
			
			if (endRange.location != NSNotFound)
			{
				NSString *pidString;
				
				if (endRange.location > 4)
				{
					pidString = [pidLine substringWithRange:NSMakeRange(4, endRange.location-4)];
					
					if (pidString.length > 0)
					{
						userClientPid = [pidString intValue];
						appName   = [pidLine substringFromIndex:endRange.location+endRange.length];
					}
				}
			}
			
			[pidLine release];
		}
		
		if ((ioDelegate != nil) && ([ioDelegate respondsToSelector:@selector(resourceMediator:trackUserClient:pid:name:)]))
		{
			track = [ioDelegate resourceMediator:self trackUserClient:userClientObj pid:userClientPid name:appName];
		}
	
		if (track)
		{
			ISResourceUser *user = nil;
			
			@synchronized(self)
			{
				if ((user = [self resourceUserForPID:userClientPid createIfNotExists:YES]) != nil)
				{
					if (user.trackingObject != nil)
					{
						if ([user.trackingObject isKindOfClass:[NSMutableArray class]])
						{
							[(NSMutableArray *)user.trackingObject addObject:userClientObj];
						}
						else
						{
							user.trackingObject = [NSMutableArray arrayWithObjects:user.trackingObject, userClientObj, nil];
						}
					}
					else
					{
						user.trackingObject = userClientObj;
					}
				}
			}
		}
	}
}

- (void)_handleUserClientTerminated:(ISIOObject *)userClientObj
{
	if (userClientObj  != nil)
	{
		@synchronized(self)
		{
			NSMutableArray *usersPendingRemoval = [NSMutableArray new];
		
			for (ISResourceUser *user in users)
			{
				if (user.trackingObject != nil)
				{
					if ([user.trackingObject isKindOfClass:[NSMutableArray class]])
					{
						if ([(NSMutableArray *)user.trackingObject containsObject:userClientObj])
						{
							[(NSMutableArray *)user.trackingObject removeObject:userClientObj];
						}
						
						if ([(NSMutableArray *)user.trackingObject count] == 0)
						{
							user.trackingObject = nil;
							
							if (!user.isUsingResourceMediator)
							{
								// Only remove users who don't use resource mediator
								[usersPendingRemoval addObject:user];
							}
						}
					}
					else
					{
						if ([user.trackingObject isEqual:userClientObj])
						{
							user.trackingObject = nil;
							
							if (!user.isUsingResourceMediator)
							{
								// Only remove users who don't use resource mediator
								[usersPendingRemoval addObject:user];
							}
						}
					}
				}
			}
			
			for (ISResourceUser *removeUser in usersPendingRemoval)
			{
				[self userTerminated:removeUser];
			}
			
			[usersPendingRemoval release];
		}
	}
}

#pragma mark - Delegates
- (void)setIoDelegate:(NSObject<ISIOResourceMediatorDelegate> *)newDelegate
{
	[newDelegate retain];
	[delegate release];
	delegate = ioDelegate = newDelegate;
}

- (void)setDelegate:(NSObject<ISResourceMediatorDelegate> *)newDelegate
{
	[self setIoDelegate:(NSObject<ISIOResourceMediatorDelegate> *)newDelegate];
}

@end

static void ISIOResourceMediatorDeviceMatchedHandler(void *refcon, io_iterator_t iterator)
{
	ISIOResourceMediator *resourceMediator = nil;

	if ((resourceMediator = (ISIOResourceMediator *)refcon) != nil)
	{
		[resourceMediator _handleDeviceMatched:iterator];
	}
}
