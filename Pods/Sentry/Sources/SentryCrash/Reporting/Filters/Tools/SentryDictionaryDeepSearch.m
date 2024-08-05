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

#import "SentryDictionaryDeepSearch.h"

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

id
sentry_objectForKeyPath(NSDictionary *dict, NSString *keyPath)
{
    return objectForKeyPath(dict, keyPath);
}
