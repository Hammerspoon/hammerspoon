// We need this because if Sentry library is added as a Framework
// the reference should be in the form of <module/header>.
// Otherwise, the reference is direct.
#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

#if __has_include(<Sentry/SentryProfilingConditionals.h>)
#    import <Sentry/SentryProfilingConditionals.h>
#else
#    import "SentryProfilingConditionals.h"
#endif
