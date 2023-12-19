#import <Foundation/Foundation.h>

/**
 * Trace sample decision flag.
 */
typedef NS_ENUM(NSUInteger, SentrySampleDecision) {
    /**
     * Used when the decision to sample a trace should be postponed.
     */
    kSentrySampleDecisionUndecided,

    /**
     * The trace should be sampled.
     */
    kSentrySampleDecisionYes,

    /**
     * The trace should not be sampled.
     */
    kSentrySampleDecisionNo
};
