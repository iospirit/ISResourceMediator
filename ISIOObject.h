//
//  ISIOObject.h
//
//  Created by Felix Schwarz on 27.10.15.
//  Copyright © 2015 IOSPIRIT GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ISIOObject : NSObject <NSCopying>
{
	io_object_t ioObject;
	UInt64 uniqueID;
}

@property(assign,nonatomic) io_object_t ioObject;
@property(assign) UInt64 uniqueID;

+ (instancetype)withIOObject:(io_object_t)object;

- (instancetype)initWithIOObject:(io_object_t)anIOObject;

- (io_object_t)IOObject;

@end
