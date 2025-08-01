// This provides convenience access to internal ObjC API of internal Swift implementation, which
// can't be directly imported in SentryPrivate.h

#import <Foundation/Foundation.h>

@class SentryClient;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

SentryUser *_Nullable sentry_getCurrentUser(void);

NS_ASSUME_NONNULL_END
