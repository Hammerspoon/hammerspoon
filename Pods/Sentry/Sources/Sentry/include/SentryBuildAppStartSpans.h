#import "SentryDefines.h"

@class SentryTracer;
@class SentrySpan;
@class SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

NSArray<SentrySpan *> *sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *appStartMeasurement);

#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END
