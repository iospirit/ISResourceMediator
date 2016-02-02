//
//  ISResourceMediator.m
//
//  Created by Felix Schwarz on 22.01.16.
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

#import "ISResourceMediator.h"

static NSString *kISResourceMediatorNotificationNamePrefix = @"com.iospirit.resourcemediator.";

static NSString *kISResourceMediatorNotificationScanNameSuffix = @"scan";
static NSString *kISResourceMediatorNotificationStatusNameSuffix = @"status";
static NSString *kISResourceMediatorNotificationAccessRequestNameSuffix = @"accessRequest";
static NSString *kISResourceMediatorNotificationAccessResponseNameSuffix = @"accessResponse";

static NSString *kISResourceMediatorNotificationResourceIdentifierKey = @"resourceIdentifier";
static NSString *kISResourceMediatorNotificationPIDKey = @"pid";
static NSString *kISResourceMediatorNotificationTargetPIDKey = @"targetPID";
static NSString *kISResourceMediatorNotificationBroadcastInfoKey = @"broadcastInfo";
static NSString *kISResourceMediatorNotificationPreferredAccessKey = @"preferredAccess";
static NSString *kISResourceMediatorNotificationActualAccessKey = @"actualAccess";
static NSString *kISResourceMediatorNotificationAccessPressureKey = @"accessPressure";
static NSString *kISResourceMediatorNotificationAccessStartTimeKey = @"accessStartTime";
static NSString *kISResourceMediatorNotificationResultKey = @"result";

#define ISResourceMediatorNotificationName(suffix)		[NSString stringWithFormat:@"%@%@.%@", kISResourceMediatorNotificationNamePrefix,resourceIdentifier,suffix]
#define kISResourceMediatorNotificationScanName			ISResourceMediatorNotificationName(kISResourceMediatorNotificationScanNameSuffix)
#define kISResourceMediatorNotificationStatusName		ISResourceMediatorNotificationName(kISResourceMediatorNotificationStatusNameSuffix)
#define kISResourceMediatorNotificationAccessRequestName	ISResourceMediatorNotificationName(kISResourceMediatorNotificationAccessRequestNameSuffix)
#define kISResourceMediatorNotificationAccessResponseName	ISResourceMediatorNotificationName(kISResourceMediatorNotificationAccessResponseNameSuffix)

@implementation ISResourceUser

@synthesize pid;

@synthesize isUsingResourceMediator;

@synthesize preferredAccess;
@synthesize actualAccess;

@synthesize broadcastInfo;
@synthesize runningApplication;

@synthesize trackingObject;

- (void)dealloc
{
	[broadcastInfo release];
	broadcastInfo = nil;
	
	[runningApplication release];
	runningApplication = nil;
	
	[trackingObject release];
	trackingObject = nil;

	[super dealloc];
}

@end

@implementation ISResourceMediator

#pragma mark - Properties
@synthesize active;

@synthesize preferredAccess;
@synthesize actualAccess;

@synthesize accessPressure;

@synthesize resourceIdentifier;
@synthesize representedObject;
@synthesize pid;

@synthesize users;

@synthesize broadcastInfo;

@synthesize delegate;

#pragma mark - Init & Dealloc
- (instancetype)initMediatorForResourceWithIdentifier:(NSString *)aResourceIdentifier delegate:(NSObject <ISResourceMediatorDelegate> *)aDelegate
{
	if ((self = [self init]) != nil)
	{
		resourceIdentifier = [aResourceIdentifier retain];
		self.delegate = aDelegate;
		
		users = [NSMutableArray new];
		usersByPID = [NSMutableDictionary new];
		pendingResponse = [NSMutableSet new];
		
		commandQueue = [NSMutableArray new];
		
		preferredAccess = kISResourceMediatorResourceAccessNone;
		actualAccess    = kISResourceMediatorResourceAccessNone;

		accessPressure = kISResourceMediatorAccessPressureOptional;

		pid = getpid();
	}
	
	return (self);
}

- (void)dealloc
{
	self.active = NO;

	[resourceIdentifier release];
	resourceIdentifier = nil;
	
	[representedObject release];
	representedObject = nil;
	
	[broadcastInfo release];
	broadcastInfo = nil;

	[lendingUser release];
	lendingUser = nil;
	
	[lentFromUser release];
	lentFromUser = nil;
	
	[usersByPID release];
	usersByPID = nil;
	
	[pendingResponse release];
	pendingResponse = nil;
	
	[commandQueue release];
	commandQueue = nil;
	
	[users release];
	users = nil;
	
	delegate = nil;

	[super dealloc];
}

#pragma mark - Start/Stop Mediator
- (void)setActive:(BOOL)newActive
{
	if (active != newActive)
	{
		active = newActive;
		
		if (active)
		{
			// Register for application events
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationNotifications:) name:NSApplicationWillTerminateNotification    object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationNotifications:) name:NSApplicationDidBecomeActiveNotification  object:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationNotifications:) name:NSApplicationWillResignActiveNotification object:nil];

			// Register for mediator notifications
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMediatorNotification:) name:kISResourceMediatorNotificationScanName		 object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMediatorNotification:) name:kISResourceMediatorNotificationStatusName	 object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMediatorNotification:) name:kISResourceMediatorNotificationAccessRequestName  object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMediatorNotification:) name:kISResourceMediatorNotificationAccessResponseName object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

			// Scan for other apps using resource
			[self _postNotificationWithName:kISResourceMediatorNotificationScanName userInfo:@{
				kISResourceMediatorNotificationPIDKey			: @(pid),
				kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier, 
			}];
			
			// Consider requesting access after giving the app some time to discover other users and get a picture of the current usage
			[self performSelector:@selector(considerRequestingAccess) withObject:nil afterDelay:0.2];
		}
		else
		{
			// Unregister from mediator notifications
			[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kISResourceMediatorNotificationScanName	    object:nil];
			[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kISResourceMediatorNotificationStatusName	    object:nil];
			[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kISResourceMediatorNotificationAccessRequestName  object:nil];
			[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kISResourceMediatorNotificationAccessResponseName object:nil];

			// Unregister from application events
			[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidBecomeActiveNotification object:nil];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationWillResignActiveNotification object:nil];
		}
	}
}

#pragma mark - Notification handling
- (void)handleApplicationNotifications:(NSNotification *)notification
{
}

- (void)handleMediatorNotification:(NSNotification *)notification
{
	// Reconstruct userInfo from NSNotification name
	// (OS X App Sandbox prohibits/prevents any NSDistributedNotifications with userInfo dictionary, but will happily accept and
	// deliver megabyte-sized (!) strings as "objects" (tested this up to 64MB), so we shouldn't hit any limit)

	NSDictionary *userInfo = nil;

	if ((notification.object != nil) && ([notification.object isKindOfClass:[NSString class]]))
	{
		NSError *error = nil;

		if ((userInfo = [NSPropertyListSerialization propertyListWithData:[notification.object dataUsingEncoding:NSUTF8StringEncoding] options:NSPropertyListImmutable format:NULL error:&error]) != nil)
		{
			if (![userInfo isKindOfClass:[NSDictionary class]])
			{
				return;
			}
		}
		else
		{
			NSLog(@"Error decoding resource mediator notification object '%@': %@", notification.object, error);
			return;
		}
	}

	[self _handleMediatorNotificationWithName:notification.name userInfo:userInfo];
}

- (void)_postNotificationWithName:(NSString *)notificationName userInfo:(NSDictionary *)notificationUserInfo
{
	NSString *notificationObjectString = nil;

	// Serialize notificationUserInfo as plist and send it as the "object" string (see -handleMediatorNotification: for an explaination)
	if (notificationUserInfo != nil)
	{
		NSError *error = nil;
		NSData *plistData = nil;

		if ((plistData = [NSPropertyListSerialization dataWithPropertyList:notificationUserInfo format:NSPropertyListXMLFormat_v1_0 options:0 error:&error]) != nil)
		{
			notificationObjectString = [[[NSString alloc] initWithData:plistData encoding:NSUTF8StringEncoding] autorelease];
		}
		else
		{
			NSLog(@"Error serializing resource mediator userInfo '%@': %@", notificationUserInfo, error);
			return;
		}
	}

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:notificationName object:notificationObjectString userInfo:nil deliverImmediately:YES];
}

- (void)_handleMediatorNotificationWithName:(NSString *)notificationName userInfo:(NSDictionary *)notificationUserInfo
{
	// Ignore notifications for which we aren't the target
	if (notificationUserInfo != nil)
	{
		NSString *targetPID = [notificationUserInfo objectForKey:kISResourceMediatorNotificationTargetPIDKey];
		
		if (targetPID != nil)
		{
			if ([targetPID intValue] != self.pid)
			{
				return;
			}
		}
	}

	// Scan / Discovery
	if ([notificationName isEqual:kISResourceMediatorNotificationScanName])
	{
		// Return information on current and desired usage
		[self postStatusNotification];
	}

	// Status updates
	if ([notificationName isEqual:kISResourceMediatorNotificationStatusName])
	{
		NSNumber *pidNumber = nil;
		ISResourceUser *user = nil;
		BOOL isNewUser = NO;
		
		if (notificationUserInfo != nil)
		{
			if ((pidNumber = [notificationUserInfo objectForKey:kISResourceMediatorNotificationPIDKey]) != nil)
			{
				@synchronized(self)
				{
					pid_t userPID = [pidNumber intValue];
				
					if ((user = [usersByPID objectForKey:@(userPID)]) == nil)
					{
						if ((user = [self _addUserForPID:userPID]) != nil)
						{
							user.isUsingResourceMediator = YES;

							isNewUser = YES;
						}
					}
					else
					{
						user.isUsingResourceMediator = YES;
					}
				}
			}
			
			if (user != nil)
			{
				NSNumber *preferredAccessNumber = nil, *actualAccessNumber = nil;
				NSDictionary *broadcastInfoDict = nil;
				
				if ((preferredAccessNumber = [notificationUserInfo objectForKey:kISResourceMediatorNotificationPreferredAccessKey]) != nil)
				{
					user.preferredAccess = [preferredAccessNumber unsignedIntegerValue];
				}
				
				if ((actualAccessNumber = [notificationUserInfo objectForKey:kISResourceMediatorNotificationActualAccessKey]) != nil)
				{
					user.actualAccess = [actualAccessNumber unsignedIntegerValue];
				}
				
				if ((broadcastInfoDict = [notificationUserInfo objectForKey:kISResourceMediatorNotificationBroadcastInfoKey]) != nil)
				{
					if ([broadcastInfoDict isKindOfClass:[NSDictionary class]])
					{
						user.broadcastInfo = broadcastInfoDict;
					}
					else
					{
						user.broadcastInfo = nil;
					}
					
					if (!isNewUser)
					{
						if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:user:updatedBroadcastInfo:)]))
						{
							[delegate resourceMediator:self user:user updatedBroadcastInfo:broadcastInfoDict];
						}
					}
				}
				
				if (isNewUser)
				{
					if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:userAppeared:)]))
					{
						[delegate resourceMediator:self userAppeared:user];
					}
				}
				else
				{
					if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:userUpdated:)]))
					{
						[delegate resourceMediator:self userUpdated:user];
					}
				}
			}
		}

		[self considerRequestingAccess];
	}
	
	// Access request
	if ([notificationName isEqual:kISResourceMediatorNotificationAccessRequestName])
	{
		NSNumber *sourceUserPIDNumber = nil;
		ISResourceMediatorAccessPressure sourceAccessPressure = kISResourceMediatorAccessPressureNone;
		NSTimeInterval sourceAccessStartTime = 0;
	
		sourceAccessPressure = [[notificationUserInfo objectForKey:kISResourceMediatorNotificationAccessPressureKey] unsignedIntegerValue];
		sourceAccessStartTime = [[notificationUserInfo objectForKey:kISResourceMediatorNotificationAccessStartTimeKey] doubleValue];
		
		if ((sourceUserPIDNumber = [notificationUserInfo objectForKey:kISResourceMediatorNotificationPIDKey]) != nil)
		{
			ISResourceUser *sourceUser = nil;
		
			if ((sourceUser = [self resourceUserForPID:[sourceUserPIDNumber intValue] createIfNotExists:YES]) != nil)
			{
				if ( (sourceAccessPressure < self.accessPressure) ||		// Do not lend access to app with lower pressure

				    ((sourceAccessPressure == self.accessPressure) &&		// Do not lend access to app with same pressure and older claim (newer claims win)
				     (sourceAccessStartTime <= accessStartTime))
				   )
				{
					// Deny access requests from apps with an access pressure lower than mine
					[self _postNotificationWithName:kISResourceMediatorNotificationAccessResponseName userInfo:@{
						kISResourceMediatorNotificationPIDKey			: @(self.pid),
						kISResourceMediatorNotificationTargetPIDKey		: sourceUserPIDNumber,
						kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier,

						kISResourceMediatorNotificationResultKey		: @(kISResourceMediatorResultDeny),
					}];
				}
				else
				{
					// Try providing access to apps with the same or a higher access pressure level
					@synchronized(self)
					{
						statusNotificationsSuspended++;
					}
					
					[self setApplicationAccessForResource:kISResourceMediatorResourceAccessNone requestedBy:sourceUser completion:^(ISResourceMediatorResult result) {
						if (result == kISResourceMediatorResultSuccess)
						{
							self.actualAccess = kISResourceMediatorResourceAccessNone;
							
							[lendingUser release];
							lendingUser = [sourceUser retain];
							lendingUserFromPreferredAccess = preferredAccess;
						}
						
						[self _postNotificationWithName:kISResourceMediatorNotificationAccessResponseName userInfo:@{
							kISResourceMediatorNotificationPIDKey			: @(self.pid),
							kISResourceMediatorNotificationTargetPIDKey		: sourceUserPIDNumber,
							kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier,

							kISResourceMediatorNotificationResultKey		: @(result),
						}];

						@synchronized(self)
						{
							if (statusNotificationsSuspended > 0)
							{
								statusNotificationsSuspended--;
							}
						}
					}];
				}
			}
		}
	}

	// Access response
	if ([notificationName isEqual:kISResourceMediatorNotificationAccessResponseName])
	{
		NSNumber *sourceUserPIDNumber = nil;
		NSNumber *resultNumber = nil;
	
		if (((sourceUserPIDNumber = [notificationUserInfo objectForKey:kISResourceMediatorNotificationPIDKey]) != nil) &&
		    ((resultNumber	  = [notificationUserInfo objectForKey:kISResourceMediatorNotificationResultKey]) != nil))
		{
			ISResourceUser *sourceUser = nil;
		
			if ((sourceUser = [self resourceUserForPID:[sourceUserPIDNumber intValue] createIfNotExists:NO]) != nil)
			{
				@synchronized(self)
				{
					ISResourceMediatorResult result = [resultNumber unsignedIntegerValue];

					if ([pendingResponse containsObject:sourceUser])
					{
						[pendingResponse removeObject:sourceUser];
					}

					if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:user:respondedToAccessRequestWith:)]))
					{
						[delegate resourceMediator:self	user:sourceUser	respondedToAccessRequestWith:result];
					}
					
					if (result == kISResourceMediatorResultSuccess)
					{
						ISResourceMediatorResourceAccess thePreferredAccess = self.preferredAccess;

						[lentFromUser release];
						lentFromUser = [sourceUser retain];

						[self setApplicationAccessForResource:thePreferredAccess requestedBy:sourceUser completion:^(ISResourceMediatorResult result) {
							if (result == kISResourceMediatorResultSuccess)
							{
								self.actualAccess = thePreferredAccess;
							}
							
							[self _postNotificationWithName:kISResourceMediatorNotificationScanName  userInfo:@{
								kISResourceMediatorNotificationPIDKey			: @(self.pid),
								kISResourceMediatorNotificationTargetPIDKey		: sourceUserPIDNumber,

								kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier,
							}];
						}];
					}
				}
			}
		}
	}
}

- (void)postStatusNotification
{
	@synchronized(self)
	{
		if (active && (statusNotificationsSuspended==0))
		{
			[self _postNotificationWithName:kISResourceMediatorNotificationStatusName userInfo:@{
				kISResourceMediatorNotificationPIDKey			: @(pid),

				kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier,
				kISResourceMediatorNotificationPreferredAccessKey	: @(self.preferredAccess),
				kISResourceMediatorNotificationActualAccessKey		: @(self.actualAccess),

				kISResourceMediatorNotificationBroadcastInfoKey		: ((broadcastInfo!=nil) ? broadcastInfo : @"")
			}];
		}
	}
}

- (void)setBroadcastInfo:(NSDictionary *)newBroadcastInfo
{
	@synchronized(self)
	{
		[newBroadcastInfo retain];
		[broadcastInfo autorelease];
		broadcastInfo = newBroadcastInfo;
		
		[self postStatusNotification];
	}
}

#pragma mark - User administration
- (ISResourceUser *)_addUserForPID:(pid_t)userPID
{
	ISResourceUser *user = nil;

	@synchronized(self)
	{
		if (userPID != self.pid)
		{
			if ((user = [[ISResourceUser alloc] init]) != nil)
			{
				user.pid = userPID;
				
				if ((user.runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:userPID]) != nil)
				{
					[user addObserver:self forKeyPath:@"runningApplication.isTerminated" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:(void *)self];
				}
			
				[users addObject:user];
				[usersByPID setObject:user forKey:@(user.pid)];
				
				[user autorelease];
			}
		}
	}
	
	return (user);
}

- (void)_removeUser:(ISResourceUser *)user
{
	@synchronized(self)
	{
		if (user.runningApplication != nil)
		{
			[user removeObserver:self forKeyPath:@"runningApplication.isTerminated" context:(void *)self];
		}
		
		[pendingResponse removeObject:user];
		
		[users removeObject:user];
		[usersByPID removeObjectForKey:@(user.pid)];
	}
}

- (ISResourceUser *)resourceUserForPID:(pid_t)userPID createIfNotExists:(BOOL)createIfNotExists
{
	ISResourceUser *user = nil;

	@synchronized(self)
	{
		if ((user = [usersByPID objectForKey:@(userPID)]) == nil)
		{
			if (createIfNotExists)
			{
				if ((user = [self _addUserForPID:userPID]) != nil)
				{
					if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:userAppeared:)]))
					{
						[delegate resourceMediator:self userAppeared:user];
					}
				}
			}
		}

		[[user retain] autorelease];
	}
	
	return (user);
}

- (void)userTerminated:(ISResourceUser *)user
{
	[self _removeUser:user];

	if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:userDisappeared:)]))
	{
		[delegate resourceMediator:self userDisappeared:user];
	}
	
	[self considerRequestingAccess];
}

- (NSMutableArray *)users
{
	NSMutableArray *usersCopy = nil;

	@synchronized(self)
	{
		usersCopy = [NSMutableArray arrayWithArray:users];
	}
	
	return (usersCopy);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
	if (context == (void*)self)
	{
		if ([keyPath isEqualToString:@"runningApplication.isTerminated"])
		{
			ISResourceUser *user = (ISResourceUser *)object;
			
			if (user != nil)
			{
				if (user.runningApplication.terminated)
				{
					[self userTerminated:user];
				}
			}
		}
	}
}

#pragma mark - Access mediation
- (void)setPreferredAccess:(ISResourceMediatorResourceAccess)newPreferredAccess
{
	if (newPreferredAccess != preferredAccess)
	{
		preferredAccess = newPreferredAccess;

		accessStartTime = [NSDate timeIntervalSinceReferenceDate];
		
		[self postStatusNotification];
		
		[self considerRequestingAccess];
	}
}

- (void)setActualAccess:(ISResourceMediatorResourceAccess)newActualAccess
{
	if (newActualAccess != actualAccess)
	{
		actualAccess = newActualAccess;
		
		@synchronized(self)
		{
			if ((actualAccess == kISResourceMediatorResourceAccessNone) && (lentFromUser != nil) && active && (statusNotificationsSuspended==0))
			{
				// Send notification to lent user in advance to give it an opportunity to be first to reclaim the resource
				[self _postNotificationWithName:kISResourceMediatorNotificationStatusName userInfo:@{
					kISResourceMediatorNotificationPIDKey			: @(pid),
					kISResourceMediatorNotificationTargetPIDKey		: @(lentFromUser.pid),

					kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier,
					kISResourceMediatorNotificationPreferredAccessKey	: @(self.preferredAccess),
					kISResourceMediatorNotificationActualAccessKey		: @(self.actualAccess),

					kISResourceMediatorNotificationBroadcastInfoKey		: ((broadcastInfo!=nil) ? broadcastInfo : @"")
				}];
				
				[lentFromUser release];
				lentFromUser = nil;
			}
			else
			{
				if (actualAccess == preferredAccess)
				{
					lendingUserFromPreferredAccess = kISResourceMediatorResourceAccessNone;
					[lendingUser release];
					lendingUser = nil;
				}
			}
		}

		// Send notification to all
		[self postStatusNotification];
		
		// Inform delegate
		if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:actualAccessChangedTo:)]))
		{
			[delegate resourceMediator:self actualAccessChangedTo:newActualAccess];
		}
	}
}

- (void)setApplicationAccessForResource:(ISResourceMediatorResourceAccess)access requestedBy:(ISResourceUser *)user completion:(void(^)(ISResourceMediatorResult result))completionHandler
{
	[self submitToCommandQueue:^(dispatch_block_t commandQueueCompletionHandler){
		if ((delegate!=nil) && ([delegate respondsToSelector:@selector(resourceMediator:setApplicationAccessForResource:requestedBy:completion:)]))
		{
			[delegate resourceMediator:self setApplicationAccessForResource:access requestedBy:user completion:^(ISResourceMediatorResult result) {
				if (completionHandler != nil)
				{
					completionHandler(result);
				}
				
				if (commandQueueCompletionHandler != nil)
				{
					commandQueueCompletionHandler();
				}
			}];
		}
		else
		{
			if (commandQueueCompletionHandler != nil)
			{
				commandQueueCompletionHandler();
			}
		}
	}];
}

- (void)requestAccessFrom:(ISResourceUser *)user
{
	if (user != nil)
	{
		[self _postNotificationWithName:kISResourceMediatorNotificationAccessRequestName userInfo:@{
			kISResourceMediatorNotificationPIDKey			: @(pid),
			kISResourceMediatorNotificationTargetPIDKey		: @(user.pid),

			kISResourceMediatorNotificationResourceIdentifierKey	: resourceIdentifier,
		}];
	}
}

- (void)considerRequestingAccess
{
	if (active)
	{
		if (preferredAccess != actualAccess)
		{
			ISResourceMediatorResourceAccess targetAccess = preferredAccess;
			
			switch (preferredAccess)
			{
				case kISResourceMediatorResourceAccessNone:
					// Return resource
					[self setApplicationAccessForResource:targetAccess requestedBy:nil completion:^(ISResourceMediatorResult result) {
						if (result == kISResourceMediatorResultSuccess)
						{
							self.actualAccess = targetAccess;
						}
					}];
				break;
				
				case kISResourceMediatorResourceAccessShared:
				case kISResourceMediatorResourceAccessBlocking:
					@synchronized(self)
					{
						BOOL resourceShouldBeAvailable = YES;
						
						for (ISResourceUser *user in users)
						{
							if (user.isUsingResourceMediator && (user.pid != pid))
							{
								// Send access request?
								if (((preferredAccess == kISResourceMediatorResourceAccessShared)   && (user.actualAccess == kISResourceMediatorResourceAccessBlocking)) ||
								    ((preferredAccess == kISResourceMediatorResourceAccessBlocking) && ((user.actualAccess == kISResourceMediatorResourceAccessShared) || (user.actualAccess == kISResourceMediatorResourceAccessBlocking))))
								{
									if ((![pendingResponse containsObject:user]) && (!((user==lendingUser) && (lendingUserFromPreferredAccess == preferredAccess))))
									{
										// Send access request
										[pendingResponse addObject:user];
										
										[self _postNotificationWithName:kISResourceMediatorNotificationAccessRequestName userInfo:@{
											kISResourceMediatorNotificationPIDKey	    : @(self.pid),
											kISResourceMediatorNotificationTargetPIDKey : @(user.pid),
											
											kISResourceMediatorNotificationAccessPressureKey    : @(self.accessPressure),
											kISResourceMediatorNotificationAccessStartTimeKey : @(accessStartTime),
											
											kISResourceMediatorNotificationResourceIdentifierKey : resourceIdentifier,
										}];
									}
									
									resourceShouldBeAvailable = NO;
								}
							}
						}
						
						if (resourceShouldBeAvailable)
						{
							// Resource should be available. Go and try grab it.
							[self setApplicationAccessForResource:targetAccess requestedBy:nil completion:^(ISResourceMediatorResult result) {
								if (result == kISResourceMediatorResultSuccess)
								{
									self.actualAccess = targetAccess;
								}
							}];
						}
					}
				break;
				
				default:
				break;
			}
		}
	}
}

#pragma mark - Command queue
- (void)submitToCommandQueue:(ISResourceMediatorCommand)asyncCommandBlock
{
	@synchronized(commandQueue)
	{
		[commandQueue addObject:[[asyncCommandBlock copy] autorelease]];
		[self tryRunningNextCommandOnQueue];
	}
}

- (void)tryRunningNextCommandOnQueue
{
	@synchronized(commandQueue)
	{
		if (!commandQueueIsExecuting)
		{
			ISResourceMediatorCommand command;
			
			if ((command = [commandQueue firstObject]) != nil)
			{
				[[command retain] autorelease];
			
				commandQueueIsExecuting = YES;
				
				[commandQueue removeObjectAtIndex:0];
				
				command(^{
					@synchronized(commandQueue)
					{
						commandQueueIsExecuting = NO;
						[self tryRunningNextCommandOnQueue];
					}
				});
			}
		}
	}
}

@end
