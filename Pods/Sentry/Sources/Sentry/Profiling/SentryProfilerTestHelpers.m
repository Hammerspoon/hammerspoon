#import "SentryProfilerTestHelpers.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryFileManager.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentrySerialization.h"

BOOL
sentry_threadSanitizerIsPresent(void)
{
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
    return YES;
#            pragma clang diagnostic push
#            pragma clang diagnostic ignored "-Wunreachable-code"
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

    return NO;
}

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)

void
sentry_writeProfileFile(NSData *JSONData)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *testProfileDirPath =
        [sentryApplicationSupportPath() stringByAppendingPathComponent:@"profiles"];

    if (![fm fileExistsAtPath:testProfileDirPath]) {
        SENTRY_LOG_DEBUG(@"Creating app support directory.");
        NSError *error;
        if (!SENTRY_CASSERT_RETURN([fm createDirectoryAtPath:testProfileDirPath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error],
                @"Failed to create sentry app support directory")) {
            return;
        }
    } else {
        SENTRY_LOG_DEBUG(@"App support directory already exists.");
    }

    NSError *error;
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:testProfileDirPath error:&error];
    if (!SENTRY_CASSERT_RETURN(contents != nil && error == nil,
            @"Failed to read contents of debug profile directory: %@.", error)) {
        return;
    }

    NSUInteger numberOfProfiles = [contents count];
    NSString *pathToWrite = [testProfileDirPath
        stringByAppendingPathComponent:[NSString stringWithFormat:@"profile%lld",
                                                 (long long)numberOfProfiles]];

    if ([fm fileExistsAtPath:pathToWrite]) {
        SENTRY_LOG_DEBUG(@"Already a profile file present; make sure to remove them right after "
                         @"using them, and that tests clean state in between so there isn't "
                         @"leftover config producing one when it isn't expected.");
    }

    SENTRY_LOG_DEBUG(@"Writing profile to file: %@.", pathToWrite);

    SENTRY_CASSERT([JSONData writeToFile:pathToWrite options:NSDataWritingAtomic error:&error],
        @"Failed to write data to path %@: %@", pathToWrite, error);
}

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
