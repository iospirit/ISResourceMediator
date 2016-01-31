# ISResourceMediator
ISResourceMediator mediates access to a constrained resource (like hardware) between applications. Compatible with OS X sandboxing.

*by [@felix_schwarz](https://twitter.com/felix_schwarz/)*

## Features

### Access mediation
ISResourceMediator helps applications to automatically negotiate about shared or exclusive access to a resource where such a mechanism is not provided by the operating system.

### Access tracking
ISResourceMediator provides and tracks a list of applications using a resource managed by it. If the managed resource is a IOKit service, the ISIOResourceMediator subclass can keep track and include information about apps that don't use ISResourceMediator, but access the hardware. If an app can't get access to a resource, it can use this information to present a list of potentially access-blocking apps to the user.

### Presence
Apart from access mediation and tracking, ISResourceMediator can also be used to advertise membership of a group, so that each member app can find other running apps belonging to the same group. Apps can also provide an NSDictionary - broadcastInfo - that contains group-specific metadata that should be available to all other members of the group.

### Compatible with OS X Sandbox
ISResourceMediator was designed to be fully compatible with the OS X Sandbox without requiring any special entitlements.


## Mediation Concepts
ISResourceMediator follows these key concepts when mediating access:

### Access pressure
There are many ways an application can use a resource. While a media player app may throw in support for a remote control as one among many features, access to the remote control can be absolutely essential for apps dedicated to making that remote control more useful.

The pressure to access the remote control is therefore greater for the remote control app than it is for the media player app.

Another way to think about access pressure is to think about it as a degree of specialization. The higher the app is specialized/specific to a resource, the more likely it is that a user installed the app to use it with that resource. Therefore, when negotiating access, apps with a higher access pressure win.

Access pressure is expressed as a value in the 0-100 range, with these values predefined:
* kISResourceMediatorAccessPressureNone: Access to the resource is not needed.
* kISResourceMediatorAccessPressureOptional: Access to the resource is optional. Use for apps that offer additional features when the resource is available to them, but which don't rely on the resource for their operation. (default)
* kISResourceMediatorAccessPressurePartiallySupport Access to the resource is partially supported. Use for apps that need the resource to offer core functionality, but which don't support all features of the resource.
* kISResourceMediatorAccessPressureRequired Access to the resource is required. Use for apps that need the resource to offer core functionality and provide support for all features of the resource.

### Start date
If two apps have the same access pressure, the app that launched more recently wins the mediation process. Because, after all, why would the user launch an app if not for using it?

### Shared vs. Blocking
If an app wants blocking (or "exclusive") access to a resource, it asks all apps currently using it in a shared or blocking fashion to relinquish access.

If an app wants shared access to a resource, it asks all apps currently using it in a blocking fashion to relinquish access.

## Adding ISResourceMediator to your project
* Add ISResourceMediator.m and ISResourceMediator.h to your project's sources
* If you manage an IOKit-based resource, also add ISIOResourceMediator.m, ISIOResourceMediator.h, ISIOObject.m, ISIOObject.h and IOKit.framework to your project.

## Usage

### Sign up for mediation
This is how to sign up for and participate in mediation.

```objc
#import "ISResourceMediator.h"

#define kMyResourceIdentifier @"my.resource"

...

@interface AppDelegate : NSObject <NSApplicationDelegate,ISResourceMediatorDelegate>
{
	ISResourceMediator *mediator;
}

@end

... 

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	if ((mediator = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:kMyResourceIdentifier delegate:self]) != nil)
	{
		// We want shared access to this resource
		mediator.preferredAccess = kISResourceMediatorResourceAccessShared;
		
		// We offer additional features when this resource is around, but will work just fine without it.
		mediator.accessPressure = kISResourceMediatorAccessPressureOptional;

		// Start participating in the mediation process and using the resource if possible
		mediator.active = YES;
	}
}

...
```

### Change/Attempt access as determined by mediation
If you participate in ISResourceMediator mediation, the only way code path in your app that attempts establishing access to the shared resource should be through this delegate method.

```objc
...

- (void)resourceMediator:(ISResourceMediator *)mediator
	setApplicationAccessForResource:(ISResourceMediatorResourceAccess)access
	requestedBy:(ISResourceUser *)user
	completion:(void(^)(ISResourceMediatorResult result))completionHandler; 
{
	// IMPORTANT: this delegate method is guaranteed to not be called again until completionHandler(result) has been called.

	if (access == kISResourceMediatorResourceAccessNone)
	{
		// Stop using the resource, then execute completionHandler with a result call

		... 

		completionHandler(kISResourceMediatorResultSuccess);
	}
	else if (access == kISResourceMediatorResourceAccessShared) // the value we provided for mediator.preferredAccess
	{
		// Start using the resource, then execute completionHandler with a result call

		...

		completionHandler(kISResourceMediatorResultSuccess);
	}
	else
	{
		// You only get access values [kISResourceMediatorResourceAccessNone, mediator.preferredAccess], so return an error for anything else
		completionHandler(kISResourceMediatorResultError);
	}
}

...
```

### Control resource usage through ISResourceMediator
You can then control access by setting the preferredAccess attribute to the respective value. ISResourceMediator will take care of calling the -resourceMediator:setApplicationAccessForResource:requestedBy:completion: delegate method as needed.

```objc
...

- (IBAction)startUsingResource
{
	// Tell ISResourceMediator that you would like to start using the resource in shared mode.
	// -resourceMediator:setApplicationAccessForResource:requestedBy:completion: will be called as needed to achieve that.

	mediator.preferredAccess = kISResourceMediatorResourceAccessShared;
}

- (IBAction)stopUsingResource
{
	// Tell ISResourceMediator that you no longer want access to the resource.
	// -resourceMediator:setApplicationAccessForResource:requestedBy:completion: will be called as needed to achieve that.

	mediator.preferredAccess = kISResourceMediatorResourceAccessNone;
}

@end
```

### Presence / Track users of the resource
If you want to know who else is interested in using the resource managed through ISResourceMediator, you'll find a IOResourceUser instance for each user in the array available through the users property.

```objc
- (NSString *)stringForLevel:(ISResourceMediatorResourceAccess)accessLevel
{
	switch (accessLevel)
	{
		case kISResourceMediatorResourceAccessUnknown:
			return (@"unknown");
		break;

		case kISResourceMediatorResourceAccessNone:
			return (@"none");
		break;

		case kISResourceMediatorResourceAccessShared:
			return (@"shared");
		break;

		case kISResourceMediatorResourceAccessBlocking:
			return (@"blocking");
		break;
	}
	
	return (@"?");
}

- (void)printUser:(ISResourceUser *)user
{
	NSLog(@"%@[%u] prefers access in %@ mode, actually accesses it in %@ mode. Broadcast Info: %@", user.runningApplication.localizedName, user.pid, [self stringForLevel:user.preferredAccess], [self stringForLevel:user.actualAccess], user.broadcastInfo);
}

- (IBAction)printUserList
{
	for (ISResourceUser *user in mediator.users)
	{
		[self printUser:user];
	}
}

- (void)resourceMediator:(ISResourceMediator *)mediator userAppeared:(ISResourceUser *)user; /*!< Called when a new user of the resource was found. */
{
	NSLog(@"User appeared:");
	[self printUser:user];
}

- (void)resourceMediator:(ISResourceMediator *)mediator userUpdated:(ISResourceUser *)user; /*!< Called when user of the resource (may have) updated its data. */
{
	NSLog(@"Information updated for user:");
	[self printUser:user];
}

- (void)resourceMediator:(ISResourceMediator *)mediator userDisappeared:(ISResourceUser *)user; /*!< Called when user is no longer interested in a resource or has been quit. */
{
	NSLog(@"User disappeared:");
	[self printUser:user];
}


```

## Resource Identifiers
Resource identifiers should take the form of "[vendor].[product-name]" in all lower case.

Examples:
Apple Remote: apple.remote
Siri Remote: apple.siri-remote

If you want to use ISResourceMediator for a new device for which no identifier exists yet, please feel free to ask and I'll add one to the list.

## License
ISResourceMediator is MIT licensed.
