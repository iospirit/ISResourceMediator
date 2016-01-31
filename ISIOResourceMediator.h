//
//  ISIOResourceMediator.h
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

#import "ISResourceMediator.h"
#import <IOKit/IOKitLib.h>
#import "ISIOObject.h"

@class ISIOResourceMediator;

@protocol ISIOResourceMediatorDelegate <NSObject,ISResourceMediatorDelegate>

@optional
- (BOOL)resourceMediator:(ISIOResourceMediator *)mediator trackDevice:(ISIOObject *)deviceService; /*!< Return YES if ISIOResourceMediator should create IOResourceUser instances corresponding to user clients. Default: YES. */
- (BOOL)resourceMediator:(ISIOResourceMediator *)mediator trackUserClient:(ISIOObject *)userClientService pid:(pid_t)pid name:(NSString *)name; /*!< Return YES if ISIOResourceMediator should create a IOResourceUser instance corresponding to this user client. Default: YES. */

@end

@interface ISIOResourceMediator : ISResourceMediator
{
	NSString *deviceClassName;
	NSString *userClientClassName;

	IONotificationPortRef notificationPortRef;
	CFRunLoopSourceRef notificationRunLoopSource;
	
	io_iterator_t deviceMatchIterator;
	
	NSMutableArray *trackedDevices;

	NSObject <ISIOResourceMediatorDelegate> *ioDelegate;
}

@property(assign,nonatomic) NSObject <ISIOResourceMediatorDelegate> *ioDelegate; // convenience accessor

#pragma mark - Init & Dealloc
- (instancetype)initMediatorForResourceWithIdentifier:(NSString *)aResourceIdentifier deviceClassName:(NSString *)deviceClassName userClientClassName:(NSString *)userClientClassName delegate:(NSObject <ISIOResourceMediatorDelegate> *)aDelegate;

@end
