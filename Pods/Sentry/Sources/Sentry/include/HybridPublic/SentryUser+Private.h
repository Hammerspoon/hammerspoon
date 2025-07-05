#if __has_include(<Sentry/SentryUser.h>)
#    import <Sentry/SentryUser.h>
#else
#    import "SentryUser.h"
#endif

@interface SentryUser ()

/**
 * Initializes a SentryUser from a dictionary.
 * @param dictionary The dictionary containing user data.
 * @return The SentryUser.
 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end
