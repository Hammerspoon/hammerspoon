// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReportFilterBasic.m
//
//  Created by Karl Stenerud on 2012-05-11.
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

#import "SentryCrashReportFilterBasic.h"
#import "Container+SentryDeepSearch.h"
#import "NSError+SentrySimpleConstructor.h"
#import "SentryCrashVarArgs.h"

// #define SentryCrashLogger_LocalLevel TRACE
#import "SentryCrashLogger.h"

@implementation SentryCrashReportFilterPassthrough

+ (SentryCrashReportFilterPassthrough *)filter
{
    return [[self alloc] init];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    sentrycrash_callCompletion(onCompletion, reports, YES, nil);
}

@end

@interface
SentryCrashReportFilterCombine ()

@property (nonatomic, readwrite, retain) NSArray *filters;
@property (nonatomic, readwrite, retain) NSArray *keys;

- (id)initWithFilters:(NSArray *)filters keys:(NSArray *)keys;

@end

@implementation SentryCrashReportFilterCombine

@synthesize filters = _filters;
@synthesize keys = _keys;

- (id)initWithFilters:(NSArray *)filters keys:(NSArray *)keys
{
    if ((self = [super init])) {
        self.filters = filters;
        self.keys = keys;
    }
    return self;
}

+ (SentryCrashVA_Block)argBlockWithFilters:(NSMutableArray *)filters andKeys:(NSMutableArray *)keys
{
    __block BOOL isKey = FALSE;
    SentryCrashVA_Block block = ^(id entry) {
        if (isKey) {
            if (entry == nil) {
                SentryCrashLOG_ERROR(@"key entry was nil");
            } else {
                [keys addObject:entry];
            }
        } else {
            if ([entry isKindOfClass:[NSArray class]]) {
                entry = [SentryCrashReportFilterPipeline filterWithFilters:entry, nil];
            }
            if (![entry conformsToProtocol:@protocol(SentryCrashReportFilter)]) {
                SentryCrashLOG_ERROR(@"Not a filter: %@", entry);
                // Cause next key entry to fail as well.
                return;
            } else {
                [filters addObject:entry];
            }
        }
        isKey = !isKey;
    };
    return [block copy];
}

+ (SentryCrashReportFilterCombine *)filterWithFiltersAndKeys:(id)firstFilter, ...
{
    NSMutableArray *filters = [NSMutableArray array];
    NSMutableArray *keys = [NSMutableArray array];
    sentrycrashva_iterate_list(firstFilter, [self argBlockWithFilters:filters andKeys:keys]);
    return [[self alloc] initWithFilters:filters keys:keys];
}

- (id)initWithFiltersAndKeys:(id)firstFilter, ...
{
    NSMutableArray *filters = [NSMutableArray array];
    NSMutableArray *keys = [NSMutableArray array];
    sentrycrashva_iterate_list(
        firstFilter, [[self class] argBlockWithFilters:filters andKeys:keys]);
    return [self initWithFilters:filters keys:keys];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSArray *filters = self.filters;
    NSArray *keys = self.keys;
    NSUInteger filterCount = [filters count];

    if (filterCount == 0) {
        sentrycrash_callCompletion(onCompletion, reports, YES, nil);
        return;
    }

    if (filterCount != [keys count]) {
        sentrycrash_callCompletion(onCompletion, reports, NO,
            [NSError sentryErrorWithDomain:[[self class] description]
                                      code:0
                               description:@"Key/filter mismatch (%d keys, %d filters",
                               [keys count], filterCount]);
        return;
    }

    NSMutableArray *reportSets = [NSMutableArray arrayWithCapacity:filterCount];

    __block NSUInteger iFilter = 0;
    __block SentryCrashReportFilterCompletion filterCompletion = nil;
    __block __weak SentryCrashReportFilterCompletion weakFilterCompletion = nil;
    dispatch_block_t disposeOfCompletion = [^{
        // Release self-reference on the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{ filterCompletion = nil; });
    } copy];
    filterCompletion = [^(NSArray *filteredReports, BOOL completed, NSError *filterError) {
        if (!completed || filteredReports == nil) {
            if (!completed) {
                sentrycrash_callCompletion(onCompletion, filteredReports, completed, filterError);
            } else if (filteredReports == nil) {
                sentrycrash_callCompletion(onCompletion, filteredReports, NO,
                    [NSError sentryErrorWithDomain:[[self class] description]
                                              code:0
                                       description:@"filteredReports was nil"]);
            }
            disposeOfCompletion();
            return;
        }

        // Normal run until all filters exhausted.
        [reportSets addObject:filteredReports];
        if (++iFilter < filterCount) {
            id<SentryCrashReportFilter> filter = [filters objectAtIndex:iFilter];
            [filter filterReports:reports onCompletion:weakFilterCompletion];
            return;
        }

        // All filters complete, or a filter failed.
        // Build final "filteredReports" array.
        NSUInteger reportCount = [(NSArray *)[reportSets objectAtIndex:0] count];
        NSMutableArray *combinedReports = [NSMutableArray arrayWithCapacity:reportCount];
        for (NSUInteger iReport = 0; iReport < reportCount; iReport++) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:filterCount];
            for (NSUInteger iSet = 0; iSet < filterCount; iSet++) {
                NSArray *reportSet = [reportSets objectAtIndex:iSet];
                if (reportSet.count > iReport) {
                    NSDictionary *report = [reportSet objectAtIndex:iReport];
                    [dict setObject:report forKey:[keys objectAtIndex:iSet]];
                }
            }
            [combinedReports addObject:dict];
        }

        sentrycrash_callCompletion(onCompletion, combinedReports, completed, filterError);
        disposeOfCompletion();
    } copy];
    weakFilterCompletion = filterCompletion;

    // Initial call with first filter to start everything going.
    id<SentryCrashReportFilter> filter = [filters objectAtIndex:iFilter];
    [filter filterReports:reports onCompletion:filterCompletion];
}

@end

@interface
SentryCrashReportFilterPipeline ()

@property (nonatomic, readwrite, retain) NSArray *filters;

@end

@implementation SentryCrashReportFilterPipeline

@synthesize filters = _filters;

+ (SentryCrashReportFilterPipeline *)filterWithFilters:(id)firstFilter, ...
{
    sentrycrashva_list_to_nsarray(firstFilter, filters);
    return [[self alloc] initWithFiltersArray:filters];
}

- (id)initWithFilters:(id)firstFilter, ...
{
    sentrycrashva_list_to_nsarray(firstFilter, filters);
    return [self initWithFiltersArray:filters];
}

- (id)initWithFiltersArray:(NSArray *)filters
{
    if ((self = [super init])) {
        NSMutableArray *expandedFilters = [NSMutableArray array];
        for (id<SentryCrashReportFilter> filter in filters) {
            if ([filter isKindOfClass:[NSArray class]]) {
                [expandedFilters addObjectsFromArray:(NSArray *)filter];
            } else {
                [expandedFilters addObject:filter];
            }
        }
        self.filters = expandedFilters;
    }
    return self;
}

- (void)addFilter:(id<SentryCrashReportFilter>)filter
{
    NSMutableArray *mutableFilters = (NSMutableArray *)self.filters; // Shh! Don't tell anyone!
    [mutableFilters insertObject:filter atIndex:0];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSArray *filters = self.filters;
    NSUInteger filterCount = [filters count];

    if (filterCount == 0) {
        sentrycrash_callCompletion(onCompletion, reports, YES, nil);
        return;
    }

    __block NSUInteger iFilter = 0;
    __block SentryCrashReportFilterCompletion filterCompletion;
    __block __weak SentryCrashReportFilterCompletion weakFilterCompletion = nil;
    dispatch_block_t disposeOfCompletion = [^{
        // Release self-reference on the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{ filterCompletion = nil; });
    } copy];
    filterCompletion = [^(NSArray *filteredReports, BOOL completed, NSError *filterError) {
        if (!completed || filteredReports == nil) {
            if (!completed) {
                sentrycrash_callCompletion(onCompletion, filteredReports, completed, filterError);
            } else if (filteredReports == nil) {
                sentrycrash_callCompletion(onCompletion, filteredReports, NO,
                    [NSError sentryErrorWithDomain:[[self class] description]
                                              code:0
                                       description:@"filteredReports was nil"]);
            }
            disposeOfCompletion();
            return;
        }

        // Normal run until all filters exhausted or one
        // filter fails to complete.
        if (++iFilter < filterCount) {
            id<SentryCrashReportFilter> filter = [filters objectAtIndex:iFilter];
            [filter filterReports:filteredReports onCompletion:weakFilterCompletion];
            return;
        }

        // All filters complete, or a filter failed.
        sentrycrash_callCompletion(onCompletion, filteredReports, completed, filterError);
        disposeOfCompletion();
    } copy];
    weakFilterCompletion = filterCompletion;

    // Initial call with first filter to start everything going.
    id<SentryCrashReportFilter> filter = [filters objectAtIndex:iFilter];
    [filter filterReports:reports onCompletion:filterCompletion];
}

@end

@interface
SentryCrashReportFilterObjectForKey ()

@property (nonatomic, readwrite, retain) id key;
@property (nonatomic, readwrite, assign) BOOL allowNotFound;

@end

@implementation SentryCrashReportFilterObjectForKey

@synthesize key = _key;
@synthesize allowNotFound = _allowNotFound;

+ (SentryCrashReportFilterObjectForKey *)filterWithKey:(id)key allowNotFound:(BOOL)allowNotFound
{
    return [[self alloc] initWithKey:key allowNotFound:allowNotFound];
}

- (id)initWithKey:(id)key allowNotFound:(BOOL)allowNotFound
{
    if ((self = [super init])) {
        self.key = key;
        self.allowNotFound = allowNotFound;
    }
    return self;
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (NSDictionary *report in reports) {
        id object = nil;
        if ([self.key isKindOfClass:[NSString class]]) {
            object = [report sentry_objectForKeyPath:self.key];
        } else {
            object = [report objectForKey:self.key];
        }
        if (object == nil) {
            if (!self.allowNotFound) {
                sentrycrash_callCompletion(onCompletion, filteredReports, NO,
                    [NSError sentryErrorWithDomain:[[self class] description]
                                              code:0
                                       description:@"Key not found: %@", self.key]);
                return;
            }
            [filteredReports addObject:[NSDictionary dictionary]];
        } else {
            [filteredReports addObject:object];
        }
    }
    sentrycrash_callCompletion(onCompletion, filteredReports, YES, nil);
}

@end

@interface
SentryCrashReportFilterConcatenate ()

@property (nonatomic, readwrite, retain) NSString *separatorFmt;
@property (nonatomic, readwrite, retain) NSArray *keys;

@end

@implementation SentryCrashReportFilterConcatenate

@synthesize separatorFmt = _separatorFmt;
@synthesize keys = _keys;

+ (SentryCrashReportFilterConcatenate *)filterWithSeparatorFmt:(NSString *)separatorFmt
                                                          keys:(id)firstKey, ...
{
    sentrycrashva_list_to_nsarray(firstKey, keys);
    return [[self alloc] initWithSeparatorFmt:separatorFmt keysArray:keys];
}

- (id)initWithSeparatorFmt:(NSString *)separatorFmt keys:(id)firstKey, ...
{
    sentrycrashva_list_to_nsarray(firstKey, keys);
    return [self initWithSeparatorFmt:separatorFmt keysArray:keys];
}

- (id)initWithSeparatorFmt:(NSString *)separatorFmt keysArray:(NSArray *)keys
{
    if ((self = [super init])) {
        NSMutableArray *realKeys = [NSMutableArray array];
        for (id key in keys) {
            if ([key isKindOfClass:[NSArray class]]) {
                [realKeys addObjectsFromArray:(NSArray *)key];
            } else {
                [realKeys addObject:key];
            }
        }

        self.separatorFmt = separatorFmt;
        self.keys = realKeys;
    }
    return self;
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (NSDictionary *report in reports) {
        BOOL firstEntry = YES;
        NSMutableString *concatenated = [NSMutableString string];
        for (NSString *key in self.keys) {
            if (firstEntry) {
                firstEntry = NO;
            } else {
                [concatenated appendFormat:self.separatorFmt, key];
            }
            id object = [report sentry_objectForKeyPath:key];
            [concatenated appendFormat:@"%@", object];
        }
        [filteredReports addObject:concatenated];
    }
    sentrycrash_callCompletion(onCompletion, filteredReports, YES, nil);
}

@end

@interface
SentryCrashReportFilterSubset ()

@property (nonatomic, readwrite, retain) NSArray *keyPaths;

@end

@implementation SentryCrashReportFilterSubset

@synthesize keyPaths = _keyPaths;

+ (SentryCrashReportFilterSubset *)filterWithKeys:(id)firstKeyPath, ...
{
    sentrycrashva_list_to_nsarray(firstKeyPath, keyPaths);
    return [[self alloc] initWithKeysArray:keyPaths];
}

- (id)initWithKeys:(id)firstKeyPath, ...
{
    sentrycrashva_list_to_nsarray(firstKeyPath, keyPaths);
    return [self initWithKeysArray:keyPaths];
}

- (id)initWithKeysArray:(NSArray *)keyPaths
{
    if ((self = [super init])) {
        NSMutableArray *realKeyPaths = [NSMutableArray array];
        for (id keyPath in keyPaths) {
            if ([keyPath isKindOfClass:[NSArray class]]) {
                [realKeyPaths addObjectsFromArray:(NSArray *)keyPath];
            } else {
                [realKeyPaths addObject:keyPath];
            }
        }

        self.keyPaths = realKeyPaths;
    }
    return self;
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (NSDictionary *report in reports) {
        NSMutableDictionary *subset = [NSMutableDictionary dictionary];
        for (NSString *keyPath in self.keyPaths) {
            id object = [report sentry_objectForKeyPath:keyPath];
            if (object == nil) {
                sentrycrash_callCompletion(onCompletion, filteredReports, NO,
                    [NSError sentryErrorWithDomain:[[self class] description]
                                              code:0
                                       description:@"Report did not have key path %@", keyPath]);
                return;
            }
            [subset setObject:object forKey:[keyPath lastPathComponent]];
        }
        [filteredReports addObject:subset];
    }
    sentrycrash_callCompletion(onCompletion, filteredReports, YES, nil);
}

@end

@implementation SentryCrashReportFilterDataToString

+ (SentryCrashReportFilterDataToString *)filter
{
    return [[self alloc] init];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (NSData *report in reports) {
        NSString *converted = [[NSString alloc] initWithData:report encoding:NSUTF8StringEncoding];
        [filteredReports addObject:converted];
    }

    sentrycrash_callCompletion(onCompletion, filteredReports, YES, nil);
}

@end

@implementation SentryCrashReportFilterStringToData

+ (SentryCrashReportFilterStringToData *)filter
{
    return [[self alloc] init];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    NSMutableArray *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (NSString *report in reports) {
        NSData *converted = [report dataUsingEncoding:NSUTF8StringEncoding];
        if (converted == nil) {
            sentrycrash_callCompletion(onCompletion, filteredReports, NO,
                [NSError sentryErrorWithDomain:[[self class] description]
                                          code:0
                                   description:@"Could not convert report to UTF-8"]);
            return;
        } else {
            [filteredReports addObject:converted];
        }
    }

    sentrycrash_callCompletion(onCompletion, filteredReports, YES, nil);
}

@end
