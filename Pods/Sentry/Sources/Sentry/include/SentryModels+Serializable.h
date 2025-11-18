#if SDK_V9
#    import "SentryBreadcrumb.h"
#    import "SentryDebugMeta.h"
#    import "SentryEnvelopeItemHeader.h"
#    import "SentryEvent.h"
#    import "SentryException.h"
#    import "SentryFrame.h"
#    import "SentryGeo.h"
#    import "SentryInternalSerializable.h"
#    import "SentryMechanism.h"
#    import "SentryMechanismMeta.h"
#    import "SentryMessage.h"
#    import "SentryNSError.h"
#    import "SentryRequest.h"
#    import "SentryScope.h"
#    import "SentryStacktrace.h"
#    import "SentryThread.h"
#    import "SentryTraceContext.h"
#    import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope () <SentryInternalSerializable>

@end

@interface SentryUser () <SentryInternalSerializable>

@end

@interface SentryEvent () <SentryInternalSerializable>

@end

@interface SentryStacktrace () <SentryInternalSerializable>

@end

@interface SentryGeo () <SentryInternalSerializable>

@end

@interface SentryFrame () <SentryInternalSerializable>

@end

@interface SentryNSError () <SentryInternalSerializable>

@end

@interface SentryMechanismMeta () <SentryInternalSerializable>

@end

@interface SentryMechanism () <SentryInternalSerializable>

@end

@interface SentryEnvelopeItemHeader () <SentryInternalSerializable>

- (NSDictionary<NSString *, id> *)serialize;

@end

@interface SentryFrame () <SentryInternalSerializable>

@end

@interface SentryDebugMeta () <SentryInternalSerializable>

@end

@interface SentryException () <SentryInternalSerializable>

@end

@interface SentryTraceContext () <SentryInternalSerializable>

- (NSDictionary<NSString *, id> *)serialize;

@end

@interface SentryMessage () <SentryInternalSerializable>

@end

@interface SentryThread () <SentryInternalSerializable>

@end

@interface SentryRequest () <SentryInternalSerializable>

@end

@interface SentryBreadcrumb () <SentryInternalSerializable>

@end

NS_ASSUME_NONNULL_END

#endif // SDK_V9
