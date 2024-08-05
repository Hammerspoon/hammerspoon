#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentrySpan;
@class SentryTracer;
@class SentryDispatchQueueWrapper;
@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief This is a class responsible for creating
 * TTID and TTFD spans.
 * @discussion This class creates the TTID and TTFD spans and make use of
 * the @c SentryTracer wait for children feature to keep transaction open long
 * enough to wait for a full display report if @c waitForFullDisplay is true.
 */
@interface SentryTimeToDisplayTracker : NSObject
SENTRY_NO_INIT

@property (nullable, nonatomic, weak, readonly) SentrySpan *initialDisplaySpan;

@property (nullable, nonatomic, weak, readonly) SentrySpan *fullDisplaySpan;

@property (nonatomic, readonly) BOOL waitForFullDisplay;

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay
             dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (void)startForTracer:(SentryTracer *)tracer;

- (void)reportInitialDisplay;

- (void)reportFullyDisplayed;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
