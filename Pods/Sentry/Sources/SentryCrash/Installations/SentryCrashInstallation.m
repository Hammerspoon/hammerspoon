// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashInstallation.m
//
//  Created by Karl Stenerud on 2013-02-10.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "SentryCrashInstallation.h"
#import "SentryAsyncSafeLog.h"
#import "SentryCrash.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryCrashJSONCodecObjC.h"
#import "SentryCrashNSErrorUtil.h"
#import "SentryCrashReportFilterBasic.h"
#import "SentryDependencyContainer.h"
#import <objc/runtime.h>

/** Max number of properties that can be defined for writing to the report */
#define kMaxProperties 500

static CrashHandlerData *g_crashHandlerData;

static void
crashCallback(const SentryCrashReportWriter *writer)
{
    for (int i = 0; i < g_crashHandlerData->reportFieldsCount; i++) {
        ReportField *field = g_crashHandlerData->reportFields[i];
        if (field->key != NULL && field->value != NULL) {
            writer->addJSONElement(writer, field->key, field->value, true);
        }
    }
    if (g_crashHandlerData->userCrashCallback != NULL) {
        g_crashHandlerData->userCrashCallback(writer);
    }
}

@interface
SentryCrashInstallation ()

@property (nonatomic, readwrite, assign) int nextFieldIndex;
@property (nonatomic, readonly, assign) CrashHandlerData *crashHandlerData;
@property (nonatomic, readwrite, retain) NSMutableData *crashHandlerDataBacking;
@property (nonatomic, readwrite, retain) NSMutableDictionary *fields;
@property (nonatomic, readwrite, retain) NSArray *requiredProperties;

@end

@implementation SentryCrashInstallation

@synthesize nextFieldIndex = _nextFieldIndex;
@synthesize crashHandlerDataBacking = _crashHandlerDataBacking;
@synthesize fields = _fields;
@synthesize requiredProperties = _requiredProperties;

- (id)init
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ does not support init. Subclasses must call "
                       @"initWithMaxReportFieldCount:requiredProperties:",
                [self class]];
    return nil;
}

- (id)initWithRequiredProperties:(NSArray *)requiredProperties
{
    if ((self = [super init])) {
        self.crashHandlerDataBacking =
            [NSMutableData dataWithLength:sizeof(*self.crashHandlerData)
                           + sizeof(*self.crashHandlerData->reportFields) * kMaxProperties];
        self.fields = [NSMutableDictionary dictionary];
        self.requiredProperties = requiredProperties;
    }
    return self;
}

- (void)dealloc
{
    SentryCrash *handler = SentryDependencyContainer.sharedInstance.crashReporter;
    @synchronized(handler) {
        if (g_crashHandlerData == self.crashHandlerData) {
            g_crashHandlerData = NULL;
            handler.onCrash = NULL;
        }
    }
}

- (CrashHandlerData *)crashHandlerData
{
    return (CrashHandlerData *)self.crashHandlerDataBacking.mutableBytes;
}

- (CrashHandlerData *)g_crashHandlerData
{
    return g_crashHandlerData;
}

- (NSError *)validateProperties
{
    NSMutableString *errors = [NSMutableString string];
    for (NSString *propertyName in self.requiredProperties) {
        NSString *nextError = nil;
        @try {
            id value = [self valueForKey:propertyName];
            if (value == nil) {
                nextError = @"is nil";
            }
        } @catch (NSException *exception) {
            nextError = @"property not found";
        }
        if (nextError != nil) {
            if ([errors length] > 0) {
                [errors appendString:@", "];
            }
            [errors appendFormat:@"%@ (%@)", propertyName, nextError];
        }
    }
    if ([errors length] > 0) {
        return sentryErrorWithDomain([[self class] description], 0,
            @"Installation properties failed validation: %@", errors);
    }
    return nil;
}

- (NSString *)makeKeyPath:(NSString *)keyPath
{
    if ([keyPath length] == 0) {
        return keyPath;
    }
    BOOL isAbsoluteKeyPath = [keyPath length] > 0 && [keyPath characterAtIndex:0] == '/';
    return isAbsoluteKeyPath ? keyPath : [@"user/" stringByAppendingString:keyPath];
}

- (NSArray *)makeKeyPaths:(NSArray *)keyPaths
{
    if ([keyPaths count] == 0) {
        return keyPaths;
    }
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[keyPaths count]];
    for (NSString *keyPath in keyPaths) {
        [result addObject:[self makeKeyPath:keyPath]];
    }
    return result;
}

- (void)install:(NSString *)customCacheDirectory
{
    SentryCrash *handler = SentryDependencyContainer.sharedInstance.crashReporter;
    @synchronized(handler) {
        handler.basePath = customCacheDirectory;
        g_crashHandlerData = self.crashHandlerData;
        handler.onCrash = crashCallback;
        [handler install];
    }
}

- (void)uninstall
{
    SentryCrash *handler = SentryDependencyContainer.sharedInstance.crashReporter;
    @synchronized(handler) {
        if (g_crashHandlerData == self.crashHandlerData) {
            g_crashHandlerData = NULL;
            handler.onCrash = NULL;
        }
        [handler uninstall];
    }
}

- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSError *error = [self validateProperties];
    if (error != nil) {
        if (onCompletion != nil) {
            onCompletion(nil, NO, error);
        }
        return;
    }

    id<SentryCrashReportFilter> sink = [self sink];
    if (sink == nil) {
        onCompletion(nil, NO,
            sentryErrorWithDomain([[self class] description], 0,
                @"Sink was nil (subclasses must implement "
                @"method \"sink\")"));
        return;
    }

    sink = [SentryCrashReportFilterPipeline filterWithFilters:sink, nil];

    SentryCrash *handler = SentryDependencyContainer.sharedInstance.crashReporter;
    handler.sink = sink;
    [handler sendAllReportsWithCompletion:onCompletion];
}

- (id<SentryCrashReportFilter>)sink
{
    return nil;
}

@end
