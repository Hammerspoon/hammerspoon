#import "SentryAppStartMeasurement.h"
#import "SentrySpan.h"
#import "SentrySpanContext+Private.h"
#import "SentrySpanId.h"
#import "SentryTraceOrigins.h"
#import "SentryTracer.h"
#import <Foundation/Foundation.h>
#import <SentryBuildAppStartSpans.h>

#if SENTRY_HAS_UIKIT

id<SentrySpan>
sentryBuildAppStartSpan(
    SentryTracer *tracer, SentrySpanId *parentId, NSString *operation, NSString *description)
{
    SentrySpanContext *context =
        [[SentrySpanContext alloc] initWithTraceId:tracer.traceId
                                            spanId:[[SentrySpanId alloc] init]
                                          parentId:parentId
                                         operation:operation
                                   spanDescription:description
                                            origin:SentryTraceOriginAutoAppStart
                                           sampled:tracer.sampled];

    return [[SentrySpan alloc] initWithTracer:tracer context:context framesTracker:nil];
}

NSArray<SentrySpan *> *
sentryBuildAppStartSpans(SentryTracer *tracer, SentryAppStartMeasurement *appStartMeasurement)
{

    if (appStartMeasurement == nil) {
        return @[];
    }

    NSString *operation;
    NSString *type;

    switch (appStartMeasurement.type) {
    case SentryAppStartTypeCold:
        operation = @"app.start.cold";
        type = @"Cold Start";
        break;
    case SentryAppStartTypeWarm:
        operation = @"app.start.warm";
        type = @"Warm Start";
        break;
    default:
        return @[];
    }

    NSMutableArray<SentrySpan *> *appStartSpans = [NSMutableArray array];

    NSDate *appStartEndTimestamp = [appStartMeasurement.appStartTimestamp
        dateByAddingTimeInterval:appStartMeasurement.duration];

    SentrySpan *appStartSpan = sentryBuildAppStartSpan(tracer, tracer.spanId, operation, type);
    [appStartSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
    [appStartSpan setTimestamp:appStartEndTimestamp];

    [appStartSpans addObject:appStartSpan];

    if (!appStartMeasurement.isPreWarmed) {
        SentrySpan *premainSpan
            = sentryBuildAppStartSpan(tracer, appStartSpan.spanId, operation, @"Pre Runtime Init");
        [premainSpan setStartTimestamp:appStartMeasurement.appStartTimestamp];
        [premainSpan setTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [appStartSpans addObject:premainSpan];

        SentrySpan *runtimeInitSpan = sentryBuildAppStartSpan(
            tracer, appStartSpan.spanId, operation, @"Runtime Init to Pre Main Initializers");
        [runtimeInitSpan setStartTimestamp:appStartMeasurement.runtimeInitTimestamp];
        [runtimeInitSpan setTimestamp:appStartMeasurement.moduleInitializationTimestamp];
        [appStartSpans addObject:runtimeInitSpan];
    }

    SentrySpan *appInitSpan
        = sentryBuildAppStartSpan(tracer, appStartSpan.spanId, operation, @"UIKit Init");
    [appInitSpan setStartTimestamp:appStartMeasurement.moduleInitializationTimestamp];
    [appInitSpan setTimestamp:appStartMeasurement.sdkStartTimestamp];
    [appStartSpans addObject:appInitSpan];

    SentrySpan *didFinishLaunching
        = sentryBuildAppStartSpan(tracer, appStartSpan.spanId, operation, @"Application Init");
    [didFinishLaunching setStartTimestamp:appStartMeasurement.sdkStartTimestamp];
    [didFinishLaunching setTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [appStartSpans addObject:didFinishLaunching];

    SentrySpan *frameRenderSpan
        = sentryBuildAppStartSpan(tracer, appStartSpan.spanId, operation, @"Initial Frame Render");
    [frameRenderSpan setStartTimestamp:appStartMeasurement.didFinishLaunchingTimestamp];
    [frameRenderSpan setTimestamp:appStartEndTimestamp];
    [appStartSpans addObject:frameRenderSpan];

    return appStartSpans;
}

#endif // SENTRY_HAS_UIKIT
