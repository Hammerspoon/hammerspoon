#import "SentryDispatchQueueProviderProtocol.h"
#import "SentryDispatchSourceProviderProtocol.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

@class SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

/**
 * A type of object that vends wrappers for dispatch queues and sources, which can be subclassed to
 * vend their mocked test subclasses.
 */
@interface SentryDispatchFactory
    : NSObject <SentryDispatchQueueProviderProtocol, SentryDispatchSourceProviderProtocol>

@end

NS_ASSUME_NONNULL_END
