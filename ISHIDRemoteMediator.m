//
//  ISHIDRemoteMediator.m
//
//  Created by Felix Schwarz on 10.02.16.
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

#import "ISHIDRemoteMediator.h"

/* Extracted from HIDRemote */
// Distributed notifications
static NSString *kHIDRemoteDNHIDRemotePing			= @"com.candelair.ping";
static NSString *kHIDRemoteDNHIDRemoteStatus			= @"com.candelair.status";

// Distributed notifications userInfo keys and values
static NSString *kHIDRemoteDNStatusPIDKey			= @"PID";
static NSString *kHIDRemoteDNStatusModeKey			= @"Mode";
static NSString *kHIDRemoteDNStatusActionKey			= @"Action";
static NSString *kHIDRemoteDNStatusActionStop			= @"stop";
/* / Extracted from HIDRemote */

@implementation ISHIDRemoteMediator

#pragma mark - Init & Dealloc
- (instancetype)initMediatorWithDelegate:(NSObject <ISResourceMediatorDelegate> *)aDelegate
{
	return ([self initMediatorForResourceWithIdentifier:@"apple.remote" deviceClassName:@"IOHIDDevice" userClientClassName:@"IOUserClient" delegate:(NSObject <ISIOResourceMediatorDelegate> *)aDelegate]);
}

#pragma mark - IR Receiver Matching
- (BOOL)trackDevice:(ISIOObject *)deviceService
{
	BOOL serviceMatches = NO;
	NSString *ioClass;
	NSNumber *candelairHIDRemoteCompatibilityMask;
	
	if (deviceService.ioObject != 0)
	{
		// IOClass matching
		if ((ioClass = (NSString *)IORegistryEntryCreateCFProperty((io_registry_entry_t)deviceService.ioObject,
									   CFSTR(kIOClassKey),
									   kCFAllocatorDefault,
									   0)) != nil)
		{
			// Match on Apple's AppleIRController and old versions of the Remote Buddy IR Controller
			if ([ioClass isEqual:@"AppleIRController"] || [ioClass isEqual:@"RBIOKitAIREmu"])
			{
				CFTypeRef candelairHIDRemoteCompatibilityDevice;

				serviceMatches = YES;
				
				if ((candelairHIDRemoteCompatibilityDevice = IORegistryEntryCreateCFProperty((io_registry_entry_t)deviceService.ioObject, CFSTR("CandelairHIDRemoteCompatibilityDevice"), kCFAllocatorDefault, 0)) != NULL)
				{
					if (CFEqual(kCFBooleanTrue, candelairHIDRemoteCompatibilityDevice))
					{
						serviceMatches = NO;
					}
					
					CFRelease (candelairHIDRemoteCompatibilityDevice);
				}
			}

			// Match on the virtual IOSPIRIT IR Controller
			if ([ioClass isEqual:@"IOSPIRITIRController"])
			{
				serviceMatches = YES;
			}
			
			CFRelease((CFTypeRef)ioClass);
		}

		// Match on services that claim compatibility with the HID Remote class (Candelair or third-party) by having a property of CandelairHIDRemoteCompatibilityMask = 1 <Type: Number>
		if ((candelairHIDRemoteCompatibilityMask = (NSNumber *)IORegistryEntryCreateCFProperty((io_registry_entry_t)deviceService.ioObject, CFSTR("CandelairHIDRemoteCompatibilityMask"), kCFAllocatorDefault, 0)) != nil)
		{
			if ([candelairHIDRemoteCompatibilityMask isKindOfClass:[NSNumber class]])
			{
				if ([candelairHIDRemoteCompatibilityMask unsignedIntValue] & kHIDRemoteCompatibilityFlagsStandardHIDRemoteDevice)
				{
					serviceMatches = YES;
				}
				else
				{
					serviceMatches = NO;
				}
			}
			
			CFRelease((CFTypeRef)candelairHIDRemoteCompatibilityMask);
		}
	}

	return (serviceMatches);
}

- (BOOL)trackUserClient:(ISIOObject *)userClientService pid:(pid_t)pid name:(NSString *)name
{
	io_object_t userClientObject;

	if ((userClientObject = userClientService.ioObject) != 0)
	{
		if (IOObjectConformsTo(userClientObject, "IOHIDLibUserClient") || IOObjectConformsTo(userClientObject, "IOHIDUserClient"))
		{
			if ([name isEqual:@"loginwindow"] || [name isEqual:@"UserEventAgent"])
			{
				return(NO);
			}
		
			return (YES);
		}
	}

	return (NO);
}

#pragma mark - Start/Stop Mediator
- (void)setActive:(BOOL)newActive
{
	if (active != newActive)
	{
		[super setActive:newActive];
		
		if (newActive)
		{
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleHIDRemoteNotification:) name:kHIDRemoteDNHIDRemoteStatus object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
			
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:kHIDRemoteDNHIDRemotePing object:nil userInfo:nil deliverImmediately:YES];
		}
		else
		{
			[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kHIDRemoteDNHIDRemoteStatus object:nil];
		}
	}
}

#pragma mark - Handle HIDRemote notifications
- (void)handleHIDRemoteNotification:(NSNotification *)notification
{
	if ([notification.name isEqual:kHIDRemoteDNHIDRemoteStatus])
	{
		NSDictionary *userInfo;
		
		if ((userInfo = [notification userInfo]) != nil)
		{
			pid_t notificationPID = (pid_t)[[userInfo objectForKey:kHIDRemoteDNStatusPIDKey] intValue];
			HIDRemoteMode remoteMode = (HIDRemoteMode)[[userInfo objectForKey:kHIDRemoteDNStatusModeKey] intValue];
			NSString *action = [userInfo objectForKey:kHIDRemoteDNStatusActionKey];
			
			if (notificationPID != 0)
			{
				if ([action isEqual:kHIDRemoteDNStatusActionStop])
				{
					[self userTerminated:[self resourceUserForPID:notificationPID createIfNotExists:NO]];
				}
				else
				{
					ISResourceUser *pidUser = nil;
					
					if ((pidUser = [self resourceUserForPID:notificationPID createIfNotExists:YES]) != nil)
					{
						ISResourceMediatorResourceAccess access = kISResourceMediatorResourceAccessUnknown;
					
						switch (remoteMode)
						{
							case kHIDRemoteModeNone:
								access = kISResourceMediatorResourceAccessNone;
							break;

							case kHIDRemoteModeShared:
								access = kISResourceMediatorResourceAccessShared;
							break;

							case kHIDRemoteModeExclusive:
							case kHIDRemoteModeExclusiveAuto:
								access = kISResourceMediatorResourceAccessBlocking;
							break;
							
							default:
								access = kISResourceMediatorResourceAccessUnknown;
							break;
						}
						
						pidUser.preferredAccess = pidUser.actualAccess = access;

						if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:userUpdated:)]))
						{
							[delegate resourceMediator:self userUpdated:pidUser];
						}
					}
				}
			}
		}
	}
}

@end
