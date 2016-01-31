//
//  ISIOResourceMediator.h
//
//  Created by Felix Schwarz on 28.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
//

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
