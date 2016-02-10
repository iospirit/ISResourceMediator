//
//  ISHIDRemoteMediator.h
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

/*
	ISHIDRemoteMediator can be used to track the use of the Apple Remote by other applications.
	
	Features:
	- adds status data from apps using HIDRemote (NOTE: this class does NOT broadcast status
	  back to HIDRemote. That would be done by the HIDRemote instance that you use to access
	  the Apple Remote in your app - and that is managed by ISHIDRemoteMediator)
	- watch the resource(s) in IOKit and track its users (for apps not using HIDRemote)
	- omits OS X daemons accessing the Apple Remote in shared mode (so they're not turning up
	  as users of the resource)
*/

#import "ISIOResourceMediator.h"

@interface ISHIDRemoteMediator : ISIOResourceMediator

#pragma mark - Init & Dealloc
- (instancetype)initMediatorWithDelegate:(NSObject <ISResourceMediatorDelegate> *)aDelegate;

@end

/* Extracted from HIDRemote */

typedef enum
{
	kHIDRemoteCompatibilityFlagsStandardHIDRemoteDevice = 1L,
} HIDRemoteCompatibilityFlags;

typedef enum
{
	kHIDRemoteModeNone = 0L,
	kHIDRemoteModeShared,		// Share the remote with others - let's you listen to the remote control events as long as noone has an exclusive lock on it
					// (RECOMMENDED ONLY FOR SPECIAL PURPOSES)

	kHIDRemoteModeExclusive,	// Try to acquire an exclusive lock on the remote (NOT RECOMMENDED)

	kHIDRemoteModeExclusiveAuto	// Try to acquire an exclusive lock on the remote whenever the application has focus. Temporarily release control over the
					// remote when another application has focus (RECOMMENDED)
} HIDRemoteMode;

/* / Extracted from HIDRemote */
