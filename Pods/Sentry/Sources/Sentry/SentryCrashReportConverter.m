#import "SentryCrashReportConverter.h"
#import "NSDate+SentryExtras.h"
#import "SentryBreadcrumb.h"
#import "SentryCrashStackCursor.h"
#import "SentryDebugMeta.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFrame.h"
#import "SentryFrameInAppLogic.h"
#import "SentryHexAddressFormatter.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentryMechanismMeta.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryUser.h"

@interface
SentryCrashReportConverter ()

@property (nonatomic, strong) NSDictionary *report;
@property (nonatomic, assign) NSInteger crashedThreadIndex;
@property (nonatomic, strong) NSDictionary *exceptionContext;
@property (nonatomic, strong) NSArray *binaryImages;
@property (nonatomic, strong) NSArray *threads;
@property (nonatomic, strong) NSDictionary *systemContext;
@property (nonatomic, strong) NSString *diagnosis;
@property (nonatomic, strong) SentryFrameInAppLogic *frameInAppLogic;

@end

@implementation SentryCrashReportConverter

- (instancetype)initWithReport:(NSDictionary *)report
               frameInAppLogic:(SentryFrameInAppLogic *)frameInAppLogic
{
    self = [super init];
    if (self) {
        self.report = report;
        self.frameInAppLogic = frameInAppLogic;
        self.systemContext = report[@"system"];
        self.userContext = report[@"user"];

        NSDictionary *crashContext;
        // This is an incomplete crash report
        if (nil != report[@"recrash_report"][@"crash"]) {
            crashContext = report[@"recrash_report"][@"crash"];
        } else {
            crashContext = report[@"crash"];
        }

        if (nil != report[@"recrash_report"][@"binary_images"]) {
            self.binaryImages = report[@"recrash_report"][@"binary_images"];
        } else {
            self.binaryImages = report[@"binary_images"];
        }

        self.diagnosis = crashContext[@"diagnosis"];
        self.exceptionContext = crashContext[@"error"];
        [self initThreads:crashContext[@"threads"]];
    }
    return self;
}

- (void)initThreads:(NSArray<NSDictionary *> *)threads
{
    if (nil != threads && [threads isKindOfClass:[NSArray class]]) {
        // SentryCrash sometimes produces recrash_reports where an element of threads is a
        // NSString instead of a NSDictionary. When this happens we can't read the details of
        // the thread, but we have to discard it. Otherwise we would crash.
        NSPredicate *onlyNSDictionary = [NSPredicate predicateWithBlock:^BOOL(id object,
            NSDictionary *bindings) { return [object isKindOfClass:[NSDictionary class]]; }];
        self.threads = [threads filteredArrayUsingPredicate:onlyNSDictionary];

        for (NSUInteger i = 0; i < self.threads.count; i++) {
            NSDictionary *thread = self.threads[i];
            if ([thread[@"crashed"] boolValue]) {
                self.crashedThreadIndex = (NSInteger)i;
                break;
            }
        }
    }
}

- (SentryEvent *_Nullable)convertReportToEvent
{
    @try {
        SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];
        if ([self.report[@"report"][@"timestamp"] isKindOfClass:NSNumber.class]) {
            event.timestamp = [NSDate
                dateWithTimeIntervalSince1970:[self.report[@"report"][@"timestamp"] integerValue]];
        } else {
            event.timestamp =
                [NSDate sentry_fromIso8601String:self.report[@"report"][@"timestamp"]];
        }
        event.debugMeta = [self convertDebugMeta];
        event.threads = [self convertThreads];
        event.exceptions = [self convertExceptions];

        event.dist = self.userContext[@"dist"];
        event.environment = self.userContext[@"environment"];
        event.context = self.userContext[@"context"];
        event.extra = self.userContext[@"extra"];
        event.tags = self.userContext[@"tags"];
        //    event.level we do not set the level here since this always resulted
        //    from a fatal crash

        event.user = [self convertUser];
        event.breadcrumbs = [self convertBreadcrumbs];

        // The releaseName must be set on the userInfo of SentryCrash.sharedInstance
        event.releaseName = self.userContext[@"release"];

        // We want to set the release and dist to the version from the crash report
        // itself otherwise it can happend that we have two different version when
        // the app crashes right before an app update #218 #219
        NSDictionary *appContext = event.context[@"app"];
        if (nil == event.releaseName && appContext[@"app_identifier"] && appContext[@"app_version"]
            && appContext[@"app_build"]) {
            event.releaseName =
                [NSString stringWithFormat:@"%@@%@+%@", appContext[@"app_identifier"],
                          appContext[@"app_version"], appContext[@"app_build"]];
        }

        if (nil == event.dist && appContext[@"app_build"]) {
            event.dist = appContext[@"app_build"];
        }

        return event;
    } @catch (NSException *exception) {
        NSString *errorMessage =
            [NSString stringWithFormat:@"Could not convert report:%@", exception.description];
        [SentryLog logWithMessage:errorMessage andLevel:kSentryLevelError];
    }

    return nil;
}

- (SentryUser *_Nullable)convertUser
{
    SentryUser *user = nil;
    if (nil != self.userContext[@"user"]) {
        NSDictionary *storedUser = self.userContext[@"user"];
        user = [[SentryUser alloc] init];
        user.userId = storedUser[@"id"];
        user.email = storedUser[@"email"];
        user.username = storedUser[@"username"];
        user.data = storedUser[@"data"];
    }
    return user;
}

- (NSMutableArray<SentryBreadcrumb *> *)convertBreadcrumbs
{
    NSMutableArray *breadcrumbs = [NSMutableArray new];
    if (nil != self.userContext[@"breadcrumbs"]) {
        NSArray *storedBreadcrumbs = self.userContext[@"breadcrumbs"];
        for (NSDictionary *storedCrumb in storedBreadcrumbs) {
            SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc]
                initWithLevel:[self sentryLevelFromString:storedCrumb[@"level"]]
                     category:storedCrumb[@"category"]];
            crumb.message = storedCrumb[@"message"];
            crumb.type = storedCrumb[@"type"];
            crumb.timestamp = [NSDate sentry_fromIso8601String:storedCrumb[@"timestamp"]];
            crumb.data = storedCrumb[@"data"];
            [breadcrumbs addObject:crumb];
        }
    }
    return breadcrumbs;
}

- (SentryLevel)sentryLevelFromString:(NSString *)level
{
    if ([level isEqualToString:@"fatal"]) {
        return kSentryLevelFatal;
    } else if ([level isEqualToString:@"warning"]) {
        return kSentryLevelWarning;
    } else if ([level isEqualToString:@"info"] || [level isEqualToString:@"log"]) {
        return kSentryLevelInfo;
    } else if ([level isEqualToString:@"debug"]) {
        return kSentryLevelDebug;
    } else if ([level isEqualToString:@"error"]) {
        return kSentryLevelError;
    }
    return kSentryLevelError;
}

- (NSArray *)rawStackTraceForThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *thread = self.threads[threadIndex];
    return thread[@"backtrace"][@"contents"];
}

- (NSDictionary *)registersForThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *thread = self.threads[threadIndex];
    NSMutableDictionary *registers = [NSMutableDictionary new];
    for (NSString *key in [thread[@"registers"][@"basic"] allKeys]) {
        [registers setValue:sentry_formatHexAddress(thread[@"registers"][@"basic"][key])
                     forKey:key];
    }
    return registers;
}

- (NSDictionary *)binaryImageForAddress:(uintptr_t)address
{
    NSDictionary *result = nil;
    for (NSDictionary *binaryImage in self.binaryImages) {
        uintptr_t imageStart = (uintptr_t)[binaryImage[@"image_addr"] unsignedLongLongValue];
        uintptr_t imageEnd
            = imageStart + (uintptr_t)[binaryImage[@"image_size"] unsignedLongLongValue];
        if (address >= imageStart && address < imageEnd) {
            result = binaryImage;
            break;
        }
    }
    return result;
}

- (SentryThread *_Nullable)threadAtIndex:(NSInteger)threadIndex
                  stripCrashedStacktrace:(BOOL)stripCrashedStacktrace
{
    if (threadIndex >= [self.threads count]) {
        return nil;
    }
    NSDictionary *threadDictionary = self.threads[threadIndex];

    SentryThread *thread = [[SentryThread alloc] initWithThreadId:threadDictionary[@"index"]];
    // We only want to add the stacktrace if this thread hasn't crashed
    thread.stacktrace = [self stackTraceForThreadIndex:threadIndex];
    if (thread.stacktrace.frames.count == 0) {
        // If we don't have any frames, we discard the whole frame
        thread.stacktrace = nil;
    }
    thread.crashed = threadDictionary[@"crashed"];
    thread.current = threadDictionary[@"current_thread"];
    thread.name = threadDictionary[@"name"];
    if (nil == thread.name) {
        thread.name = threadDictionary[@"dispatch_queue"];
    }
    return thread;
}

- (SentryFrame *)stackFrameAtIndex:(NSInteger)frameIndex inThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *frameDictionary = [self rawStackTraceForThreadIndex:threadIndex][frameIndex];
    uintptr_t instructionAddress
        = (uintptr_t)[frameDictionary[@"instruction_addr"] unsignedLongLongValue];
    NSDictionary *binaryImage = [self binaryImageForAddress:instructionAddress];
    SentryFrame *frame = [[SentryFrame alloc] init];
    frame.symbolAddress = sentry_formatHexAddress(frameDictionary[@"symbol_addr"]);
    frame.instructionAddress = sentry_formatHexAddress(frameDictionary[@"instruction_addr"]);
    frame.imageAddress = sentry_formatHexAddress(binaryImage[@"image_addr"]);
    frame.package = binaryImage[@"name"];
    BOOL isInApp = [self.frameInAppLogic isInApp:binaryImage[@"name"]];
    frame.inApp = @(isInApp);
    if (frameDictionary[@"symbol_name"]) {
        frame.function = frameDictionary[@"symbol_name"];
    }
    return frame;
}

// We already get all the frames in the right order
- (NSArray<SentryFrame *> *)stackFramesForThreadIndex:(NSInteger)threadIndex
{
    NSUInteger frameCount = [self rawStackTraceForThreadIndex:threadIndex].count;
    if (frameCount <= 0) {
        return [NSArray new];
    }

    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:frameCount];
    SentryFrame *lastFrame = nil;

    for (NSInteger i = 0; i < frameCount; i++) {
        NSDictionary *frameDictionary = [self rawStackTraceForThreadIndex:threadIndex][i];
        uintptr_t instructionAddress
            = (uintptr_t)[frameDictionary[@"instruction_addr"] unsignedLongLongValue];
        if (instructionAddress == SentryCrashSC_ASYNC_MARKER) {
            if (lastFrame != nil) {
                lastFrame.stackStart = @(YES);
            }
            // skip the marker frame
            continue;
        }
        lastFrame = [self stackFrameAtIndex:i inThreadIndex:threadIndex];
        [frames addObject:lastFrame];
    }

    return [[frames reverseObjectEnumerator] allObjects];
}

- (SentryStacktrace *)stackTraceForThreadIndex:(NSInteger)threadIndex
{
    NSArray<SentryFrame *> *frames = [self stackFramesForThreadIndex:threadIndex];
    SentryStacktrace *stacktrace =
        [[SentryStacktrace alloc] initWithFrames:frames
                                       registers:[self registersForThreadIndex:threadIndex]];
    [stacktrace fixDuplicateFrames];
    return stacktrace;
}

- (SentryThread *_Nullable)crashedThread
{
    return [self threadAtIndex:self.crashedThreadIndex stripCrashedStacktrace:NO];
}

- (NSArray<SentryDebugMeta *> *)convertDebugMeta
{
    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray new];
    for (NSDictionary *sourceImage in self.binaryImages) {
        SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
        debugMeta.uuid = sourceImage[@"uuid"];
        debugMeta.type = @"apple";
        // We default to 0 on the server if not sent
        if ([sourceImage[@"image_vmaddr"] integerValue] > 0) {
            debugMeta.imageVmAddress = sentry_formatHexAddress(sourceImage[@"image_vmaddr"]);
        }
        debugMeta.imageAddress = sentry_formatHexAddress(sourceImage[@"image_addr"]);
        debugMeta.imageSize = sourceImage[@"image_size"];
        debugMeta.name = sourceImage[@"name"];
        [result addObject:debugMeta];
    }
    return result;
}

- (NSArray<SentryException *> *_Nullable)convertExceptions
{
    if (nil == self.exceptionContext) {
        return nil;
    }
    NSString *const exceptionType = self.exceptionContext[@"type"] ?: @"Unknown Exception";
    SentryException *exception = nil;
    if ([exceptionType isEqualToString:@"nsexception"]) {
        exception = [self parseNSException];
    } else if ([exceptionType isEqualToString:@"cpp_exception"]) {
        exception =
            [[SentryException alloc] initWithValue:self.exceptionContext[@"cpp_exception"][@"name"]
                                              type:@"C++ Exception"];
    } else if ([exceptionType isEqualToString:@"mach"]) {
        exception = [[SentryException alloc]
            initWithValue:[NSString stringWithFormat:@"Exception %@, Code %@, Subcode %@",
                                    self.exceptionContext[@"mach"][@"exception"],
                                    self.exceptionContext[@"mach"][@"code"],
                                    self.exceptionContext[@"mach"][@"subcode"]]
                     type:self.exceptionContext[@"mach"][@"exception_name"]];
    } else if ([exceptionType isEqualToString:@"signal"]) {
        exception = [[SentryException alloc]
            initWithValue:[NSString stringWithFormat:@"Signal %@, Code %@",
                                    self.exceptionContext[@"signal"][@"signal"],
                                    self.exceptionContext[@"signal"][@"code"]]
                     type:self.exceptionContext[@"signal"][@"name"]];
    } else if ([exceptionType isEqualToString:@"user"]) {
        NSString *exceptionReason =
            [NSString stringWithFormat:@"%@", self.exceptionContext[@"reason"]];
        exception = [[SentryException alloc]
            initWithValue:exceptionReason
                     type:self.exceptionContext[@"user_reported"][@"name"]];

        NSRange match = [exceptionReason rangeOfString:@":"];
        if (match.location != NSNotFound) {
            exception = [[SentryException alloc]
                initWithValue:[[exceptionReason
                                  substringWithRange:NSMakeRange(match.location + match.length,
                                                         (exceptionReason.length - match.location)
                                                             - match.length)]
                                  stringByTrimmingCharactersInSet:[NSCharacterSet
                                                                      whitespaceCharacterSet]]
                         type:[exceptionReason substringWithRange:NSMakeRange(0, match.location)]];
        }
    } else {
        exception = [[SentryException alloc] initWithValue:@"Unknown Exception" type:exceptionType];
    }

    [self enhanceValueFromNotableAddresses:exception];
    exception.mechanism = [self extractMechanismOfType:exceptionType];

    SentryThread *crashedThread = [self crashedThread];
    exception.threadId = crashedThread.threadId;
    exception.stacktrace = crashedThread.stacktrace;

    if (nil != self.diagnosis && self.diagnosis.length > 0
        && ![self.diagnosis containsString:exception.value]) {
        exception.value = [exception.value
            stringByAppendingString:[NSString stringWithFormat:@" >\n%@", self.diagnosis]];
    }
    return @[ exception ];
}

- (SentryException *)parseNSException
{
    NSString *reason = @"";
    if (nil != self.exceptionContext[@"nsexception"][@"reason"]) {
        reason = self.exceptionContext[@"nsexception"][@"reason"];
    } else if (nil != self.exceptionContext[@"reason"]) {
        reason = self.exceptionContext[@"reason"];
    }

    return [[SentryException alloc] initWithValue:[NSString stringWithFormat:@"%@", reason]
                                             type:self.exceptionContext[@"nsexception"][@"name"]];
}

- (void)enhanceValueFromNotableAddresses:(SentryException *)exception
{
    // Gatekeeper fixes https://github.com/getsentry/sentry-cocoa/issues/231
    if ([self.threads count] == 0 || self.crashedThreadIndex >= [self.threads count]) {
        return;
    }
    NSDictionary *crashedThread = self.threads[self.crashedThreadIndex];
    NSDictionary *notableAddresses = crashedThread[@"notable_addresses"];
    NSMutableOrderedSet *reasons = [[NSMutableOrderedSet alloc] init];
    if (nil != notableAddresses) {
        for (id key in notableAddresses) {
            NSDictionary *content = notableAddresses[key];
            if ([content[@"type"] isEqualToString:@"string"] && nil != content[@"value"]) {
                // if there are less than 3 slashes it shouldn't be a filepath
                if ([[content[@"value"] componentsSeparatedByString:@"/"] count] < 3) {
                    [reasons addObject:content[@"value"]];
                }
            }
        }
    }
    if (reasons.count > 0) {
        exception.value =
            [[[reasons array] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                componentsJoinedByString:@" > "];
    }
}

- (SentryMechanism *_Nullable)extractMechanismOfType:(nonnull NSString *)type
{
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:type];
    if (nil != self.exceptionContext[@"mach"]) {
        mechanism.handled = @(NO);

        SentryMechanismMeta *meta = [[SentryMechanismMeta alloc] init];

        NSMutableDictionary *machException = [NSMutableDictionary new];
        [machException setValue:self.exceptionContext[@"mach"][@"exception_name"] forKey:@"name"];
        [machException setValue:self.exceptionContext[@"mach"][@"exception"] forKey:@"exception"];
        [machException setValue:self.exceptionContext[@"mach"][@"subcode"] forKey:@"subcode"];
        [machException setValue:self.exceptionContext[@"mach"][@"code"] forKey:@"code"];
        meta.machException = machException;

        if (nil != self.exceptionContext[@"signal"]) {
            NSMutableDictionary *signal = [NSMutableDictionary new];
            [signal setValue:self.exceptionContext[@"signal"][@"signal"] forKey:@"number"];
            [signal setValue:self.exceptionContext[@"signal"][@"code"] forKey:@"code"];
            [signal setValue:self.exceptionContext[@"signal"][@"code_name"] forKey:@"code_name"];
            [signal setValue:self.exceptionContext[@"signal"][@"name"] forKey:@"name"];
            meta.signal = signal;
        }

        mechanism.meta = meta;

        if (nil != self.exceptionContext[@"address"] &&
            [self.exceptionContext[@"address"] integerValue] > 0) {
            mechanism.data = @{
                @"relevant_address" : sentry_formatHexAddress(self.exceptionContext[@"address"])
            };
        }
    }
    return mechanism;
}

- (NSArray *)convertThreads
{
    NSMutableArray *result = [NSMutableArray new];
    for (NSInteger threadIndex = 0; threadIndex < (NSInteger)self.threads.count; threadIndex++) {
        SentryThread *thread = [self threadAtIndex:threadIndex stripCrashedStacktrace:YES];
        if (thread && nil != thread.stacktrace) {
            [result addObject:thread];
        }
    }
    return result;
}

@end
