//
//  MediatorTests.m
//  MediatorTests
//
//  Created by Felix Schwarz on 27.01.16.
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

#import <XCTest/XCTest.h>
#import "ISResourceMediator.h"
#import "ScarceResource.h"

@interface MediatorTests : XCTestCase <ISResourceMediatorDelegate>
{
	ISResourceMediator *mediatorA;
	ISResourceMediator *mediatorB;
	ISResourceMediator *mediatorC;
	ISResourceMediator *mediatorD;
	
	ScarceResource *scarceResource;
	
	void (^mediatorAccessChangedBlock)(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess);
}

@property (copy) void (^mediatorAccessChangedBlock)(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess);

@end

@implementation MediatorTests

@synthesize mediatorAccessChangedBlock;

- (void)setUp
{
	[super setUp];

	mediatorA = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:@"mediator.test" delegate:self];
	mediatorB = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:@"mediator.test" delegate:self];
	mediatorC = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:@"mediator.test" delegate:self];
	mediatorD = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:@"mediator.test" delegate:self];

	mediatorA.pid = 0x100A;
	mediatorB.pid = 0x100B;
	mediatorC.pid = 0x100C;
	mediatorD.pid = 0x100D;

	scarceResource = [[ScarceResource alloc] init];
}

- (void)tearDown
{
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"< =======================" object:nil];

	[mediatorA setActive:NO];
	[mediatorA release];
	mediatorA = nil;

	[mediatorB setActive:NO];
	[mediatorB release];
	mediatorB = nil;

	[mediatorC setActive:NO];
	[mediatorC release];
	mediatorC = nil;

	[mediatorD setActive:NO];
	[mediatorD release];
	mediatorD = nil;
	
	[scarceResource release];
	scarceResource = nil;

	[mediatorAccessChangedBlock release];
	mediatorAccessChangedBlock = nil;

	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testScarceResource
{
	NSString *objA = @"A", *objB = @"B";

	XCTAssert([scarceResource trySharedLockWithObject:objA],     @"Cannot acquire shared lock");
	XCTAssert([scarceResource tryExclusiveLockWithObject:objB],  @"Cannot acquire exclusive lock");
	XCTAssert(![scarceResource tryExclusiveLockWithObject:objA], @"Can acquire second exclusive lock");
	XCTAssert(![scarceResource trySharedLockWithObject:objA],    @"Can acquire shared lock while exclusive lock is held");

	[scarceResource unlockWithObject:objA];
	XCTAssert(![scarceResource tryExclusiveLockWithObject:objA], @"Can acquire second exclusive lock");

	[scarceResource unlockWithObject:objB];
	XCTAssert([scarceResource tryExclusiveLockWithObject:objA],  @"Cannot acquire new exclusive lock after old one was released");
}

- (void)testOneSharedLock
{
	XCTestExpectation *medACanAccessShared = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation *medACanAccessShared2 = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= One Shared Lock >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
			}
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
				{
					[medACanAccessShared2 fulfill];
				}
			});
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;

	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testOneExclusiveLock
{
	XCTestExpectation *medACanAccessBlock = [self expectationWithDescription:@"Mediator A can access resource in blocking mode"];
	XCTestExpectation *medACanAccessBlock2 = [self expectationWithDescription:@"Mediator A can access resource in blocking mode"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= One Blocking Lock >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medACanAccessBlock fulfill];
			}
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if (mediatorA.actualAccess == kISResourceMediatorResourceAccessBlocking)
				{
					[medACanAccessBlock2 fulfill];
				}
			});
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessBlocking;
	mediatorA.active = YES;

	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testTwoSharedLocks
{
	XCTestExpectation *medACanAccessShared = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation *medBCanAccessShared = [self expectationWithDescription:@"Mediator B can access resource in shared mode"];
	XCTestExpectation *medABCanAccessShared = [self expectationWithDescription:@"Mediator A & B can access resource in shared mode"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= Two Shared Locks >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
			}
		}

		if (mediator == mediatorB)
		{
			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medBCanAccessShared fulfill];
			}
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessShared) && 
				    (mediatorB.actualAccess == kISResourceMediatorResourceAccessShared))
				{
					[medABCanAccessShared fulfill];
				}
			});
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;

	mediatorB.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorB.active = YES;

	[self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testOneSharedOneExclusiveLock
{
	XCTestExpectation *medACanAccessShared = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation *medBCanAccessBlocking = [self expectationWithDescription:@"Mediator B can access resource in blocking mode"];
	XCTestExpectation *medABCanAccess = [self expectationWithDescription:@"Mediator A has no access, B has access in blocking mode"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= One Shared One Exclusive Lock >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
			}
		}

		if (mediator == mediatorB)
		{
			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medBCanAccessBlocking fulfill];
				
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessNone) && 
					    (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking))
					{
						[medABCanAccess fulfill];
					}
				});
			}
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorB.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorB.active = YES;
	});

	[self waitForExpectationsWithTimeout:1.5 handler:nil];
}

- (void)testOneSharedTwoExclusivesLock
{
	XCTestExpectation __block *medACanAccessShared = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation __block *medBCanAccessBlocking = [self expectationWithDescription:@"Mediator B can access resource in blocking mode"];
	XCTestExpectation __block *medCCanAccessBlocking = [self expectationWithDescription:@"Mediator C can access resource in blocking mode"];
	XCTestExpectation *medABCCanAccess = [self expectationWithDescription:@"Mediator A has no access, B has access in blocking mode"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= One Shared Two Exclusive Locks >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
				medACanAccessShared = nil;
			}
		}

		if (mediator == mediatorB)
		{
			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medBCanAccessBlocking fulfill];
				medBCanAccessBlocking = nil;
			}
		}

		if (mediator == mediatorC)
		{
			if (mediatorC.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medCCanAccessBlocking fulfill];
				medCCanAccessBlocking = nil;
			}
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessNone) && 
				    (mediatorB.actualAccess == kISResourceMediatorResourceAccessNone) &&
				    (mediatorC.actualAccess == kISResourceMediatorResourceAccessBlocking))
				{
					[medABCCanAccess fulfill];
				}
			});
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorB.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorB.active = YES;
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorC.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorC.active = YES;
	});

	[self waitForExpectationsWithTimeout:1.5 handler:nil];
}


- (void)testOneSharedTwoExclusivesLockReturnChain
{
	XCTestExpectation __block *medACanAccessShared   = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation __block *medBCanAccessBlocking = [self expectationWithDescription:@"Mediator B can access resource in blocking mode"];
	XCTestExpectation __block *medCCanAccessBlocking = [self expectationWithDescription:@"Mediator C can access resource in blocking mode"];
	XCTestExpectation *medABCCanAccess = [self expectationWithDescription:@"Mediator A has no access, B has access in blocking mode, C has no access"];
	XCTestExpectation *medABCCanAccessReverse = [self expectationWithDescription:@"Mediator A has access, B,C have no access"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= One Shared Two Exclusive Locks Return Chain >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
				medACanAccessShared = nil;
			}
		}

		if (mediator == mediatorB)
		{
			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medBCanAccessBlocking fulfill];
				medBCanAccessBlocking = nil;
			}
		}

		if (mediator == mediatorC)
		{
			if (mediatorC.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medCCanAccessBlocking fulfill];
				medCCanAccessBlocking = nil;
				
				mediatorC.preferredAccess = kISResourceMediatorResourceAccessNone;

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessNone) && 
					    (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking) &&
					    (mediatorC.actualAccess == kISResourceMediatorResourceAccessNone))
					{
						[medABCCanAccess fulfill];
						
						mediatorB.preferredAccess = kISResourceMediatorResourceAccessNone;

						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessShared) && 
							    (mediatorB.actualAccess == kISResourceMediatorResourceAccessNone) &&
							    (mediatorC.actualAccess == kISResourceMediatorResourceAccessNone))
							{
								[medABCCanAccessReverse fulfill];
							}
						});
					}
				});
			}
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorB.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorB.active = YES;
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorC.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorC.active = YES;
	});

	[self waitForExpectationsWithTimeout:1.5 handler:nil];
}

- (void)testAccessPressure
{
	XCTestExpectation __block *medACanAccessShared = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation __block *medBCanAccessBlocking = [self expectationWithDescription:@"Mediator B can access resource in blocking mode"];
	XCTestExpectation *medABCCanAccess = [self expectationWithDescription:@"Mediator A has no access, B has access in blocking mode, C no access"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= Access Pressure >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
				medACanAccessShared = nil;
			}
		}

		if (mediator == mediatorB)
		{
			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medBCanAccessBlocking fulfill];
				medBCanAccessBlocking = nil;
			}
			
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessNone) && 
				    (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking) &&
				    (mediatorC.actualAccess == kISResourceMediatorResourceAccessNone))
				{
					[medABCCanAccess fulfill];
				}
			});
		}

		if (mediator == mediatorC)
		{
			XCTAssert((mediatorC.actualAccess != kISResourceMediatorResourceAccessBlocking), @"Mediator C got blocking access - superior access pressure of Mediator B ignored?");
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorB.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorB.accessPressure = kISResourceMediatorAccessPressureRequired;
		mediatorB.active = YES;
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorC.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorC.active = YES;
	});

	[self waitForExpectationsWithTimeout:1.5 handler:nil];
}

- (void)testAccessPressureChange
{
	XCTestExpectation __block *medACanAccessShared = [self expectationWithDescription:@"Mediator A can access resource in shared mode"];
	XCTestExpectation __block *medBCanAccessBlocking = [self expectationWithDescription:@"Mediator B can access resource in blocking mode"];
	XCTestExpectation __block *medBRelinquishedBlockingAccess = [self expectationWithDescription:@"Mediator C did relinquish resource in blocking mode"];
	XCTestExpectation __block *medCCanAccessBlocking = [self expectationWithDescription:@"Mediator C can access resource in blocking mode"];
	XCTestExpectation *medABCCanAccess = [self expectationWithDescription:@"Mediator A has no access, B has no access, C has access in blocking mode"];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"======================= Access Pressure Change >" object:nil];

	self.mediatorAccessChangedBlock = ^(ISResourceMediator *mediator, ISResourceMediatorResourceAccess actualAccess){
		if (mediator == mediatorA)
		{
			if (mediatorA.actualAccess == kISResourceMediatorResourceAccessShared)
			{
				[medACanAccessShared fulfill];
				medACanAccessShared = nil;
			}
		}

		if (mediator == mediatorB)
		{
			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medBCanAccessBlocking fulfill];
				medBCanAccessBlocking = nil;
			}

			if (mediatorB.actualAccess == kISResourceMediatorResourceAccessNone)
			{
				[medBRelinquishedBlockingAccess fulfill];
				medBRelinquishedBlockingAccess = nil;
			
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					if ((mediatorA.actualAccess == kISResourceMediatorResourceAccessNone) && 
					    (mediatorB.actualAccess == kISResourceMediatorResourceAccessNone) &&
					    (mediatorC.actualAccess == kISResourceMediatorResourceAccessBlocking))
					{
						[medABCCanAccess fulfill];
					}
				});
			}
		}

		if (mediator == mediatorC)
		{
			if (mediatorC.actualAccess == kISResourceMediatorResourceAccessBlocking)
			{
				[medCCanAccessBlocking fulfill];
				medCCanAccessBlocking = nil;
			}
		}
	};

	mediatorA.preferredAccess = kISResourceMediatorResourceAccessShared;
	mediatorA.active = YES;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorB.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorB.accessPressure = kISResourceMediatorAccessPressureRequired;
		mediatorB.active = YES;
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorC.preferredAccess = kISResourceMediatorResourceAccessBlocking;
		mediatorC.active = YES;
	});


	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		mediatorB.accessPressure = kISResourceMediatorAccessPressurePartiallySupported;
		mediatorC.accessPressure = kISResourceMediatorAccessPressureRequired;
	});

	[self waitForExpectationsWithTimeout:10.5 handler:nil];
}


- (void)resourceMediator:(ISResourceMediator *)mediator setApplicationAccessForResource:(ISResourceMediatorResourceAccess)access requestedBy:(ISResourceUser *)user completion:(void (^)(ISResourceMediatorResult))completionHandler
{
	ISResourceMediatorResult result = kISResourceMediatorResultError;

	switch (access)
	{
		case kISResourceMediatorResourceAccessNone:
			[scarceResource unlockWithObject:mediator];
			result = kISResourceMediatorResultSuccess;
		break;
		
		case kISResourceMediatorResourceAccessShared:
			if ([scarceResource trySharedLockWithObject:mediator])
			{
				result = kISResourceMediatorResultSuccess;
			}
		break;
		
		case kISResourceMediatorResourceAccessBlocking:
			if ([scarceResource tryExclusiveLockWithObject:mediator])
			{
				result = kISResourceMediatorResultSuccess;
			}
		break;
		
		default:
		break;
	}
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		completionHandler(result);
	});
}

- (void)resourceMediator:(ISResourceMediator *)mediator actualAccessChangedTo:(ISResourceMediatorResourceAccess)actualAccess
{
	if (mediatorAccessChangedBlock!=nil)
	{
		NSString *actualAccessString = @"";
	
		switch (actualAccess)
		{
			case kISResourceMediatorResourceAccessNone:
				actualAccessString = @"none";
			break;

			case kISResourceMediatorResourceAccessShared:
				actualAccessString = @"shared";
			break;

			case kISResourceMediatorResourceAccessBlocking:
				actualAccessString = @"blocking";
			break;

			case kISResourceMediatorResourceAccessUnknown:
				actualAccessString = @"unknown";
			break;
		}
	
		NSLog(@"Actual Access change of %x => %@", mediator.pid, [actualAccessString uppercaseString]);
		mediatorAccessChangedBlock(mediator, actualAccess);
	}
}

- (void)resourceMediator:(ISResourceMediator *)mediator user:(ISResourceUser *)user respondedToAccessRequestWith:(ISResourceMediatorResult)accessRequestResponse
{
	NSString *accessRequestResponseString = @"";

	switch (accessRequestResponse)
	{
		case kISResourceMediatorResultSuccess:
			accessRequestResponseString = @"success";
		break;

		case kISResourceMediatorResultError:
			accessRequestResponseString = @"error";
		break;

		case kISResourceMediatorResultDeny:
			accessRequestResponseString = @"denied";
		break;
	}
	
	NSLog(@"Access Request: %x -> %x => %@", mediator.pid, user.pid, accessRequestResponseString);
}

@end
