#ifndef SentrySwift_h
#define SentrySwift_h

#ifdef __cplusplus
#    if __has_include(<MetricKit/MetricKit.h>)
#        import <MetricKit/MetricKit.h>
#    endif
#endif

#if __has_include(<SentryWithoutUIKit/Sentry.h>)
#    if __has_include("SentryWithoutUIKit-Swift.h")
#        import "SentryWithoutUIKit-Swift.h"
#    else
#        import <SentryWithoutUIKit/SentryWithoutUIKit-Swift.h>
#    endif
#else // !__has_include(<SentryWithoutUIKit/Sentry.h>)

// needed for the check for SENTRY_HAS_UIKIT below
#    if __has_include(<Sentry/SentryDefines.h>)
#        import <Sentry/SentryDefines.h>
#    else
#        import "SentryDefines.h"
#    endif // __has_include(<Sentry/SentryDefines.h>)

#    if SENTRY_HAS_UIKIT
// this is needed to fix a build issue when building iOS-ObjectiveC where the definitions of some
// UIKIt enums used from SentryUserFeedbackWidgetConfiguration.swift aren't visible from the
// generated ObjC interface for that class in Sentry-Swift.h
#        import <UIKit/UIKit.h>
#    endif // SENTRY_HAS_UIKIT

#    if __has_include("Sentry-Swift.h")
#        import "Sentry-Swift.h"
#    elif __has_include(<Sentry/Sentry-Swift.h>)
#        import <Sentry/Sentry-Swift.h>
#    else
@import SentrySwift;
#    endif
#endif // __has_include(<SentryWithoutUIKit/Sentry.h>)

#endif
