// Adapted from: https://github.com/kstenerud/KSCrash
//
//  Container+DeepSearch
//
//  Created by Karl Stenerud on 2012-08-25.
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

#import "Container+SentryDeepSearch.h"

#pragma mark - Base functionality

static BOOL
isNumericString(NSString *str)
{
    if ([str length] == 0) {
        return YES;
    }
    unichar ch = [str characterAtIndex:0];
    return ch >= '0' && ch <= '9';
}

static id
objectForDeepKey(id container, NSArray *deepKey)
{
    for (id key in deepKey) {
        if ([container respondsToSelector:@selector(objectForKey:)]) {
            container = [(NSDictionary *)container objectForKey:key];
        } else {
            if ([container respondsToSelector:@selector(objectAtIndex:)] &&
                [key respondsToSelector:@selector(intValue)]) {
                if ([key isKindOfClass:[NSString class]] && !isNumericString(key)) {
                    return nil;
                }
                NSUInteger index = (NSUInteger)[key intValue];
                container = [container objectAtIndex:index];
            } else {
                return nil;
            }
        }
        if (container == nil) {
            break;
        }
    }
    return container;
}

static id
objectForKeyPath(id container, NSString *keyPath)
{
    while ([keyPath length] > 0 && [keyPath characterAtIndex:0] == '/') {
        keyPath = [keyPath substringFromIndex:1];
    }
    return objectForDeepKey(container, [keyPath componentsSeparatedByString:@"/"]);
}

static id
parentOfDeepKey(id container, NSArray *deepKey)
{
    NSUInteger deepKeyCount = [deepKey count];
    if (deepKeyCount == 1) {
        return container;
    }

    NSArray *parentKey = [deepKey subarrayWithRange:NSMakeRange(0, deepKeyCount - 1)];
    id parent = objectForDeepKey(container, parentKey);
    if (parent == nil) {
        NSString *reason =
            [NSString stringWithFormat:@"Parent %@ does not resolve to a valid object", parentKey];
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:reason
                                     userInfo:nil];
    }
    return parent;
}

static void
setObjectForDeepKey(id container, id object, NSArray *deepKey)
{
    if ([deepKey count] == 0) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:[NSString stringWithFormat:@"deepKey %@ must contain "
                                                                         @"at least one key",
                                                        deepKey]
                                     userInfo:nil];
    }
    NSString *excFormat = nil;
    id lastKey = [deepKey objectAtIndex:[deepKey count] - 1];
    id parentContainer = parentOfDeepKey(container, deepKey);
    if ([parentContainer respondsToSelector:@selector(setObject:forKey:)]) {
        [(NSMutableDictionary *)parentContainer setObject:object forKey:lastKey];
        return;
    } else if ([lastKey respondsToSelector:@selector(intValue)]) {
        if ([parentContainer respondsToSelector:@selector(replaceObjectAtIndex:withObject:)]) {
            NSUInteger index = (NSUInteger)[lastKey intValue];
            [(NSMutableArray *)parentContainer replaceObjectAtIndex:index withObject:object];
            return;
        } else {
            excFormat = @"Parent %@ of type %@ does not respond to "
                        @"\"setObject:forKey:\" or "
                        @"\"replaceObjectAtIndex:withObject:\"";
        }
    } else {
        excFormat = @"Parent %@ of type %@ does not respond to \"setObject:forKey:\"";
    }

    NSArray *parentKey = [deepKey subarrayWithRange:NSMakeRange(0, [deepKey count] - 1)];
    NSString *reason = [NSString stringWithFormat:excFormat, parentKey, [parentContainer class]];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

static void
setObjectForKeyPath(id container, id object, NSString *keyPath)
{
    setObjectForDeepKey(container, object, [keyPath componentsSeparatedByString:@"/"]);
}

static void
removeObjectForDeepKey(id container, NSArray *deepKey)
{
    NSString *excFormat = nil;
    id lastKey = [deepKey objectAtIndex:[deepKey count] - 1];
    id parentContainer = parentOfDeepKey(container, deepKey);
    if ([parentContainer respondsToSelector:@selector(removeObjectForKey:)]) {
        [(NSMutableDictionary *)parentContainer removeObjectForKey:lastKey];
        return;
    } else if ([lastKey respondsToSelector:@selector(intValue)]) {
        if ([parentContainer respondsToSelector:@selector(removeObjectAtIndex:)]) {
            NSUInteger index = (NSUInteger)[lastKey intValue];
            [(NSMutableArray *)parentContainer removeObjectAtIndex:index];
            return;
        } else {
            excFormat = @"Parent %@ of type %@ does not respond to "
                        @"\"removeObjectForKey:\" or \"removeObjectAtIndex:\"";
        }
    } else {
        excFormat = @"Parent %@ of type %@ does not respond to "
                    @"\"removeObjectForKey:\"";
    }

    NSArray *parentKey = [deepKey subarrayWithRange:NSMakeRange(0, [deepKey count] - 1)];
    NSString *reason = [NSString stringWithFormat:excFormat, parentKey, [parentContainer class]];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

static void
removeObjectForKeyPath(id container, NSString *keyPath)
{
    removeObjectForDeepKey(container, [keyPath componentsSeparatedByString:@"/"]);
}

#pragma mark - NSDictionary Category

@implementation
NSDictionary (DeepSearch)

- (id)sentry_objectForDeepKey:(NSArray *)deepKey
{
    return objectForDeepKey(self, deepKey);
}

- (id)sentry_objectForKeyPath:(NSString *)keyPath
{
    return objectForKeyPath(self, keyPath);
}

- (void)sentry_setObject:(id)anObject forDeepKey:(NSArray *)deepKey
{
    setObjectForDeepKey(self, anObject, deepKey);
}

- (void)sentry_setObject:(id)anObject forKeyPath:(NSString *)keyPath
{
    setObjectForKeyPath(self, anObject, keyPath);
}

- (void)sentry_removeObjectForDeepKey:(NSArray *)deepKey
{
    removeObjectForDeepKey(self, deepKey);
}

- (void)sentry_removeObjectForKeyPath:(NSString *)keyPath
{
    removeObjectForKeyPath(self, keyPath);
}

@end

#pragma mark - NSArray Category

@implementation
NSArray (DeepSearch)

- (id)sentry_objectForDeepKey:(NSArray *)deepKey
{
    return objectForDeepKey(self, deepKey);
}

- (id)sentry_objectForKeyPath:(NSString *)keyPath
{
    return objectForKeyPath(self, keyPath);
}

- (void)sentry_setObject:(id)anObject forDeepKey:(NSArray *)deepKey
{
    setObjectForDeepKey(self, anObject, deepKey);
}

- (void)sentry_setObject:(id)anObject forKeyPath:(NSString *)keyPath
{
    setObjectForKeyPath(self, anObject, keyPath);
}

- (void)sentry_removeObjectForDeepKey:(NSArray *)deepKey
{
    removeObjectForDeepKey(self, deepKey);
}

- (void)sentry_removeObjectForKeyPath:(NSString *)keyPath
{
    removeObjectForKeyPath(self, keyPath);
}

@end

@interface sentrycrashobjc_DeepSearchP5EM1B9 : NSObject
@end
@implementation sentrycrashobjc_DeepSearchP5EM1B9
@end
