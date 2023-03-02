#import "SentryEvent.h"
#import <Foundation/Foundation.h>

@interface
SentryEvent (Private)

/**
 * This indicates whether this event is a result of a crash.
 */
@property (nonatomic) BOOL isCrashEvent;
@property (nonatomic, strong) NSArray *serializedBreadcrumbs;

@end
