//
//  AppDelegate.m
//  MediatorDemo
//
//  Created by Felix Schwarz on 22.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
//

#import "AppDelegate.h"
#import "ISIOResourceMediator.h"
#import "ISHIDRemoteMediator.h"

typedef NS_ENUM(NSInteger, TrackingMode)
{
	kTrackingModeVirtual = 0,
	kTrackingModeAppleRemote,
	kTrackingModeHIDRemote
};

@interface AppDelegate () <ISIOResourceMediatorDelegate, ISResourceMediatorDelegate, NSTableViewDataSource>

@property(retain) IBOutlet NSWindow *window;

@property(assign) IBOutlet NSSegmentedControl *trackingModeSelector;

@property(assign) IBOutlet NSTextField *identifierTextField;
@property(assign) IBOutlet NSTextField *pidTextField;

@property(assign) IBOutlet NSPopUpButton *preferredAccessPopupButton;
@property(assign) IBOutlet NSPopUpButton *actualAccessPopupButton;
@property(assign) IBOutlet NSPopUpButton *accessPressurePopupButton;

@property(assign) IBOutlet NSButton *activeCheckboxButton;

@property(assign) IBOutlet NSTableView *usersTableView;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	mediator = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:@"mediator.demo" delegate:self];
	// Insert code here to initialize your application
	
	self.identifierTextField.stringValue = mediator.resourceIdentifier;
	self.activeCheckboxButton.state = mediator.active ? NSOnState : NSOffState;
	
	self.pidTextField.stringValue = [NSString stringWithFormat:@"%d", mediator.pid];
	
	[self.preferredAccessPopupButton selectItemAtIndex:mediator.preferredAccess];
	[self.actualAccessPopupButton selectItemAtIndex:mediator.actualAccess];
	
	self.usersTableView.dataSource = self;
	
	switch (mediator.accessPressure)
	{
		case kISResourceMediatorAccessPressureNone:
			[self.accessPressurePopupButton selectItemAtIndex:0];
		break;

		case kISResourceMediatorAccessPressureOptional:
			[self.accessPressurePopupButton selectItemAtIndex:1];
		break;

		case kISResourceMediatorAccessPressurePartiallySupported:
			[self.accessPressurePopupButton selectItemAtIndex:2];
		break;

		case kISResourceMediatorAccessPressureRequired:
			[self.accessPressurePopupButton selectItemAtIndex:3];
		break;
	}
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	// Insert code here to tear down your application
}

- (void)setupTrackingMode:(TrackingMode)mode
{
	mediator.preferredAccess = kISResourceMediatorResourceAccessNone;
	mediator.active = NO;
	[mediator autorelease];
	mediator = nil;

	switch (mode)
	{
		case kTrackingModeVirtual:
			mediator = [[ISResourceMediator alloc] initMediatorForResourceWithIdentifier:@"mediator.demo" delegate:self];
		break;

		case kTrackingModeAppleRemote:
			mediator = [[ISIOResourceMediator alloc] initMediatorForResourceWithIdentifier:@"apple.remote" deviceClassName:@"IOHIDDevice" userClientClassName:@"IOUserClient" delegate:self];
		break;

		case kTrackingModeHIDRemote:
			mediator = [[ISHIDRemoteMediator alloc] initMediatorWithDelegate:self];
		break;
	}
	
	mediator.active = ([self.activeCheckboxButton state] == NSOnState);
}

#pragma mark - UI click handling
- (IBAction)makeChange:(id)sender
{
	if (sender == self.trackingModeSelector)
	{
		[self setupTrackingMode:self.trackingModeSelector.selectedSegment];
	}

	if (sender == self.activeCheckboxButton)
	{
		mediator.active = (self.activeCheckboxButton.state == NSOnState);
	}
	
	if (sender == self.preferredAccessPopupButton)
	{
		mediator.preferredAccess = [self.preferredAccessPopupButton indexOfSelectedItem];
	}
	
	if (sender == self.actualAccessPopupButton)
	{
		mediator.actualAccess = [self.actualAccessPopupButton indexOfSelectedItem];
	}
	
	if (sender == self.accessPressurePopupButton)
	{
		switch ([self.accessPressurePopupButton indexOfSelectedItem])
		{
			case 0:
				mediator.accessPressure = kISResourceMediatorAccessPressureNone;
			break;

			case 1:
				mediator.accessPressure = kISResourceMediatorAccessPressureOptional;
			break;

			case 2:
				mediator.accessPressure = kISResourceMediatorAccessPressurePartiallySupported;
			break;

			case 3:
				mediator.accessPressure = kISResourceMediatorAccessPressureRequired;
			break;
		}
	}
}

#pragma mark - Table view
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

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return ([mediator.users count]);
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSArray *users = mediator.users;
	
	if ((row>=0) && (row<[users count]))
	{
		ISResourceUser *user = [users objectAtIndex:row];
	
		if ([tableColumn.identifier isEqual:@"pid"])
		{
			return ([@(user.pid) stringValue]);
		}

		if ([tableColumn.identifier isEqual:@"name"])
		{
			return (user.runningApplication.localizedName);
		}

		if ([tableColumn.identifier isEqual:@"preferred"])
		{
			return ([self stringForLevel:user.preferredAccess]);
		}

		if ([tableColumn.identifier isEqual:@"actual"])
		{
			return ([self stringForLevel:user.actualAccess]);
		}
	}
	
	return (nil);
}

#pragma mark - Resource Mediator delegate
- (void)resourceMediator:(ISResourceMediator *)mediator actualAccessChangedTo:(ISResourceMediatorResourceAccess)actualAccess
{
	[self.actualAccessPopupButton selectItemAtIndex:actualAccess];
}

- (void)resourceMediator:(ISResourceMediator *)mediator setApplicationAccessForResource:(ISResourceMediatorResourceAccess)access requestedBy:(ISResourceUser *)user completion:(void (^)(ISResourceMediatorResult))completionHandler
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		completionHandler(kISResourceMediatorResultSuccess);
	});
}

- (void)resourceMediator:(ISResourceMediator *)mediator userAppeared:(ISResourceUser *)user
{
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		[self.usersTableView reloadData];
	}];
}

- (void)resourceMediator:(ISResourceMediator *)mediator userDisappeared:(ISResourceUser *)user
{
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		[self.usersTableView reloadData];
	}];
}

- (void)resourceMediator:(ISResourceMediator *)mediator userUpdated:(ISResourceUser *)user
{
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		[self.usersTableView reloadData];
	}];
}

#pragma mark - IO Resource Mediator IOKit delegate
- (BOOL)resourceMediator:(ISIOResourceMediator *)mediator trackDevice:(ISIOObject *)deviceService
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

- (BOOL)resourceMediator:(ISIOResourceMediator *)mediator trackUserClient:(ISIOObject *)userClientService pid:(pid_t)pid name:(NSString *)name
{
	io_object_t userClientObject;

	if ((userClientObject = userClientService.ioObject) != 0)
	{
		if (IOObjectConformsTo(userClientObject, "IOHIDLibUserClient") || IOObjectConformsTo(userClientObject, "IOHIDUserClient"))
		{
			return (YES);
		}
	}

	return (NO);
}

@end
