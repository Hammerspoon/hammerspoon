#import "SentryCompiler.h"
#import "SentryProfilingConditionals.h"
#import <stdbool.h>
#import <stdint.h>

SENTRY_EXTERN_C_BEGIN

/**
 * Given a fractional amount of seconds in a @c double from a Cocoa API like @c -[NSDate
 * @c timeIntervalSinceDate:], return an integer representing the amount of nanoseconds.
 */
uint64_t timeIntervalToNanoseconds(double seconds);

/** Converts integer nanoseconds to a @c NSTimeInterval. */
double nanosecondsToTimeInterval(uint64_t nanoseconds);

/**
 * Returns the absolute timestamp, which has no defined reference point or unit
 * as it is platform dependent.
 */
uint64_t getAbsoluteTime(void);

/**
 * Check whether two timestamps provided as 64 bit unsigned integers are in normal
 * chronological order, as a convenience runtime check before using @c getDurationNs.
 * Equal timestamps are considered to be valid chronological order.
 * @return @c true if @c a<=b, otherwise return @c false.
 * @note Negating the return value implies @c a>b .
 */
bool orderedChronologically(uint64_t a, uint64_t b);

/**
 * Returns the duration in nanoseconds between two absolute timestamps.
 * @warning if @c startTimestamp is actually a later timestamp than @c endTimestamp,
 * this will return @c 0, as subtracting a greater value from a lesser value in unsigned integers
 * will underflow, producing undefined behavior. Always check the magnitudes before calling
 * this function, see @c orderedChronologically for a convenient utility to do so.
 */
uint64_t getDurationNs(uint64_t startTimestamp, uint64_t endTimestamp);

SENTRY_EXTERN_C_END
