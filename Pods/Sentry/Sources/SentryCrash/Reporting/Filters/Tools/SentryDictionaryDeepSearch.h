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

/** Deep key search based methods for hierarchical container structures.
 *
 * A deep key search works like a normal search, except that the "key" is
 * interpreted as a series of keys, to be recursively applied in a "drill down"
 * fashion. There are two variants of each: the "deep key" variant, where the
 * key series is passed as an array, and the "key path" variant, where the
 * key series is passed as a serialized path, similar to filesystem paths
 * (a string where entries are separated by slashes).
 *
 * For example, if objectForDeepKey were called with [@"top", @"sublevel", @"2",
 * @"item] (or objectForKeyPath were called with @"top/sublevel/2/item"), it
 * would search as follows:
 *
 *    result = [self objectForKey:@"top"];
 *    result = [result objectForKey:@"sublevel"];
 *    result = [result objectForKey:@"2"];
 *    result = [result objectForKey:@"item"];
 *
 * Note that if any potential container along the way does not respond to
 * "objectForKey:", it will check to see if the container responds to
 * "objectAtIndex:" AND the current key responds to "intValue". If both do
 * respond, it will retrieve the current result using an array lookup:
 *
 *    result = [result objectAtIndex:[currentKey intValue]];
 */

#import <Foundation/Foundation.h>

/** Do a deep search using the specified keys.
 *
 * A failed lookup returns nil, except in the case of a failed array-style
 * lookup, in which case it may throw an "index out of range" exception.
 *
 * @param keyPath A full key path, separated by slash (e.g. @"a/b/c")
 */
id sentry_objectForKeyPath(NSDictionary *dict, NSString *keyPath);
