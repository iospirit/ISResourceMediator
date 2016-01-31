//
//  AppDelegate.h
//  MediatorDemo
//
//  Created by Felix Schwarz on 22.01.16.
//  Copyright © 2016 IOSPIRIT GmbH. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ISResourceMediator.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
	ISResourceMediator *mediator;
}

@end

