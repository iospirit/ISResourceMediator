//
//  ISResourceMediator.h
//
//  Created by Felix Schwarz on 22.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
     @abstract Represents different access patterns to a shared resource.
     @constant kISResourceMediatorResourceAccessUnknown  Application accesses resource, but the exact access pattern is unknown. ** DO NOT USE: reserved for integration with apps that don't use ISResourceMediator. **
     @constant kISResourceMediatorResourceAccessNone	 Application is not accessing the resource..
     @constant kISResourceMediatorResourceAccessShared	 Application shares access to the resource with other apps.
     @constant kISResourceMediatorResourceAccessBlocking Application has blocking/exclusive access to the resource.
*/
typedef NS_ENUM(NSUInteger, ISResourceMediatorResourceAccess)
{
	kISResourceMediatorResourceAccessUnknown,

	kISResourceMediatorResourceAccessNone,
	kISResourceMediatorResourceAccessShared,
	kISResourceMediatorResourceAccessBlocking 
};

/*!
     @abstract Result of an operation.
     @constant kISResourceMediatorResultSuccess  The operation succeeded.
     @constant kISResourceMediatorResultError	 There was an error executing the operation.
     @constant kISResourceMediatorResultDeny	 The operation was rejected by the application.
*/
typedef NS_ENUM(NSUInteger, ISResourceMediatorResult)
{
	kISResourceMediatorResultSuccess,
	kISResourceMediatorResultError,
	kISResourceMediatorResultDeny
};

/*!
     @abstract The pressure with which access to the resource is needed 
     @constant kISResourceMediatorAccessPressureNone			Access to the resource is not needed.
     @constant kISResourceMediatorAccessPressureOptional		Access to the resource is optional. Use for apps that offer additional features when the resource is available to them, but which don't rely on the resource for their operation. (default)
     @constant kISResourceMediatorAccessPressurePartiallySupport	Access to the resource is partially supported. Use for apps that need the resource to offer core functionality, but which don't support all features of the resource.
     @constant kISResourceMediatorAccessPressureRequired		Access to the resource is required. Use for apps that need the resource to offer core functionality and provide support for all features of the resource.
*/
typedef NS_ENUM(NSUInteger, ISResourceMediatorAccessPressure)
{
	kISResourceMediatorAccessPressureNone		   = 0,
	kISResourceMediatorAccessPressureOptional	   = 25,
	kISResourceMediatorAccessPressurePartiallySupport  = 50,
	kISResourceMediatorAccessPressureRequired	   = 100
};

typedef void(^ISResourceMediatorCommand)(dispatch_block_t completionHandler);

@class ISResourceMediator;
@class ISResourceUser;

@protocol ISResourceMediatorDelegate <NSObject>

/*!
Change the application's use of the resource to match the definition of the supplied ISResourceMediatorResourceAccess value.

The app will only receive the values kISResourceMediatorResourceAccessNone and the value of the preferredAccess-property.

When you're done performing the changes, call the supplied completion handler to tell the mediator about the result:

kISResourceMediatorResultSuccess if you made the change or your app is already accessing the resource accordingly

kISResourceMediatorResultError if an error occured in trying to make the change

kISResourceMediatorResultDeny if you don't want to make the change.

IMPORTANT: Because ISResourceMediator takes measures to ensure that this delegate method is not called again before the completionHandler() has signaled completion, ISResourceMediator will stop working if you don't call the completionHandler in your code.
*/
- (void)resourceMediator:(ISResourceMediator *)mediator setApplicationAccessForResource:(ISResourceMediatorResourceAccess)access requestedBy:(ISResourceUser *)user completion:(void(^)(ISResourceMediatorResult result))completionHandler; 

@optional
- (void)resourceMediator:(ISResourceMediator *)mediator userAppeared:(ISResourceUser *)user; /*!< Called when a new user of the resource was found. */
- (void)resourceMediator:(ISResourceMediator *)mediator userUpdated:(ISResourceUser *)user; /*!< Called when user of the resource (may have) updated its data. */
- (void)resourceMediator:(ISResourceMediator *)mediator userDisappeared:(ISResourceUser *)user; /*!< Called when user is no longer interested in a resource or has been quit. */

- (void)resourceMediator:(ISResourceMediator *)mediator actualAccessChangedTo:(ISResourceMediatorResourceAccess)actualAccess; /*!< Called to notify about changes to actual resource access. */

- (void)resourceMediator:(ISResourceMediator *)mediator user:(ISResourceUser *)user respondedToAccessRequestWith:(ISResourceMediatorResult)accessRequestResponse; /*!< Called after sending a response to an access request from another app. */

- (void)resourceMediator:(ISResourceMediator *)mediator user:(ISResourceUser *)user updatedBroadcastInfo:(NSDictionary *)newBroadcastInfo;  /*!< Called when a user (may have) updated its broadcast info. */

@end

@interface ISResourceUser : NSObject
{
	pid_t pid;
	
	BOOL isUsingResourceMediator;

	ISResourceMediatorResourceAccess preferredAccess;
	ISResourceMediatorResourceAccess actualAccess;
	
	NSDictionary *broadcastInfo;
	
	NSRunningApplication *runningApp;
	
	id trackingObject;
}

@property(assign) pid_t pid;

@property(assign) BOOL isUsingResourceMediator;

@property(assign) ISResourceMediatorResourceAccess preferredAccess;
@property(assign) ISResourceMediatorResourceAccess actualAccess;

@property(retain) NSDictionary *broadcastInfo;

@property(retain) NSRunningApplication *runningApplication;

@property(retain) id trackingObject;

@end

@interface ISResourceMediator : NSObject
{
	NSString *resourceIdentifier;
	id representedObject;
	
	NSDictionary *broadcastInfo;
	
	ISResourceMediatorResourceAccess preferredAccess;
	ISResourceMediatorResourceAccess actualAccess;
	
	pid_t pid;
	
	NSObject <ISResourceMediatorDelegate> *delegate;
	
	BOOL active;
	NSTimeInterval accessStartTime;
	
	NSMutableSet<ISResourceUser *> *pendingResponse;
	ISResourceMediatorResourceAccess lendingUserFromPreferredAccess;
	ISResourceUser *lendingUser;
	ISResourceUser *lentFromUser;  // matters only for lending blocking access, so keeping track of one source is sufficient. For shared access, by definition, the order of apps requesting shared access should not matter.
	
	ISResourceMediatorAccessPressure accessPressure;
	
	NSInteger statusNotificationsSuspended;
	
	NSMutableDictionary <NSNumber *, ISResourceUser *> *usersByPID;
	NSMutableArray <ISResourceUser *> *users;

	NSMutableArray *commandQueue;
	BOOL commandQueueIsExecuting;
}

@property(retain,readonly) NSString *resourceIdentifier; //!< Identifier of the resource to manage.
@property(retain) id representedObject; //!< A representedObject for your own, internal use. Not used by resource mediator.

@property(retain,nonatomic) NSDictionary *broadcastInfo; //!< A NSDictionary containing additional information to be broadcast to other ISResourceMediator users. Must consist of objects that are serializable to a property list.

@property(assign) pid_t pid; //!< Usually the PID of the running application. Made assignable to allow automated tests as well as to manage a resource for another process.

@property(assign,nonatomic) BOOL active; //!< Start/Stop resource mediator.

@property(assign,nonatomic) ISResourceMediatorResourceAccess preferredAccess; //!< A ISResourceMediatorResourceAccess value indicating how the application would like to access the resource. This value is used in -resourceMediator:setApplicationAccessForResource:completion:
@property(assign,nonatomic) ISResourceMediatorResourceAccess actualAccess; //!< A ISResourceMediatorResourceAccess value indicating how the application is currently accessing the resource.

@property(assign,nonatomic) ISResourceMediatorAccessPressure accessPressure; //!< A ISResourceMediatorAccessPressure value indicating how strongly the application needs access to the resource. The stronger an application needs a resource, the higher this value. The idea here is to follow the user's intent in running different applications targeting the same resource: if a user f.ex. installs a media player supporting a remote, but also runs an application to enhance that remote, it's highly likely the user wants the enhancer to take control. Using the pressure value allows the ISResourceMediator instances to automatically release access and claim access to the resource in a way that fits this. Please see the descriptions of the available ISResourceMediatorAccessPressure values to determine which one is right for your application. If unsure, don't set this property. A default value of kISResourceMediatorAccessPressureOptional will then be used.

@property(retain,readonly,nonatomic) NSMutableArray *users; //!< Array of ISResourceUser instances - one for each active user of the resource managed by ISResourceMediator.

@property(assign,nonatomic) NSObject <ISResourceMediatorDelegate> *delegate; //!< Recipient of ISResourceMediatorDelegate delegate method calls.

#pragma mark - Init & Dealloc
- (instancetype)initMediatorForResourceWithIdentifier:(NSString *)aResourceIdentifier delegate:(NSObject <ISResourceMediatorDelegate> *)aDelegate;

#pragma mark - Access mediation
- (void)considerRequestingAccess;

#pragma mark - User management
- (ISResourceUser *)resourceUserForPID:(pid_t)userPID createIfNotExists:(BOOL)createIfNotExists;
- (void)userTerminated:(ISResourceUser *)user;

@end
