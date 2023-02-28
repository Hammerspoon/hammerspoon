#import "SentryCompiler.h"
#import "SentryProfilingConditionals.h"
#import <stdint.h>

SENTRY_EXTERN_C_BEGIN

/**
 * Given a fractional amount of seconds in a @c double from a Cocoa API like @c -[NSDate @c
 * timeIntervalSinceDate:], return an integer representing the amount of nanoseconds.
 */
uint64_t timeIntervalToNanoseconds(double seconds);

/**
 * Returns the absolute timestamp, which has no defined reference point or unit
 * as it is platform dependent.
 */
uint64_t getAbsoluteTime(void);

/**
 * Returns the duration in nanoseconds between two absolute timestamps.
 */
uint64_t getDurationNs(uint64_t startTimestamp, uint64_t endTimestamp);

SENTRY_EXTERN_C_END
