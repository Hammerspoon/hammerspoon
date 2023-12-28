#import <Foundation/Foundation.h>

// 2 for the 0x prefix, plus 16 for the hex value, plus 1 for the null terminator
#define SENTRY_HEX_ADDRESS_LENGTH 19

static inline NSString *
sentry_snprintfHexAddress(uint64_t value)
{
    char buffer[SENTRY_HEX_ADDRESS_LENGTH];
    snprintf(buffer, SENTRY_HEX_ADDRESS_LENGTH, "0x%016llx", value);
    NSString *nsString = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    return nsString;
}

static inline NSString *
sentry_stringForUInt64(uint64_t value)
{
    int bufferSize = snprintf(NULL, 0, "%llu", value) + 1;
    char *buffer = (char *)malloc(bufferSize);
    snprintf(buffer, bufferSize, "%llu", value);
    NSString *nsString = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    free(buffer);
    return nsString;
}

static inline NSString *
sentry_formatHexAddress(NSNumber *value)
{
    /*
     * We observed a 41% speedup by using snprintf vs +[NSString stringWithFormat:]. In a trial
     * using a profile, we observed the +[NSString stringWithFormat:] using 282ms of CPU time, vs
     * 164ms of CPU time for snprintf. There is also an assumed space improvement due to not needing
     * to allocate as many instances of NSString, like for the format string literal, instead only
     * using stack-bound C strings.
     */
    return sentry_snprintfHexAddress([value unsignedLongLongValue]);
}

static inline NSString *
sentry_formatHexAddressUInt64(uint64_t value)
{
    return sentry_snprintfHexAddress(value);
}
