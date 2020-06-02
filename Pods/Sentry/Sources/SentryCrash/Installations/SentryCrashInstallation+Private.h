//
//  SentryCrashReportFieldProperties.h
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


/** Implement a property to be used as a "key". */
#define IMPLEMENT_REPORT_KEY_PROPERTY(NAME, NAMEUPPER) \
@synthesize NAME##Key = _##NAME##Key; \
- (void) set##NAMEUPPER##Key:(NSString*) value \
{ \
    _##NAME##Key; \
    _##NAME##Key = value; \
    [self reportFieldForProperty:@#NAME setKey:value]; \
}

/** Implement a property to be used as a "value". */
#define IMPLEMENT_REPORT_VALUE_PROPERTY(NAME, NAMEUPPER, TYPE) \
@synthesize NAME = _##NAME; \
- (void) set##NAMEUPPER:(TYPE) value \
{ \
    _##NAME; \
    _##NAME = value; \
    [self reportFieldForProperty:@#NAME setValue:value]; \
}

/** Implement a standard report property (with key and value properties) */
#define IMPLEMENT_REPORT_PROPERTY(NAME, NAMEUPPER, TYPE) \
IMPLEMENT_REPORT_VALUE_PROPERTY(NAME, NAMEUPPER, TYPE) \
IMPLEMENT_REPORT_KEY_PROPERTY(NAME, NAMEUPPER)


@interface SentryCrashInstallation ()

/** Initializer.
 *
 * @param requiredProperties Properties that MUST be set when sending reports.
 */
- (id) initWithRequiredProperties:(NSArray*) requiredProperties;

/** Set the key to be used for the specified report property.
 *
 * @param propertyName The name of the property.
 * @param key The key to use.
 */
- (void) reportFieldForProperty:(NSString*) propertyName setKey:(id) key;

/** Set the value of the specified report property.
 *
 * @param propertyName The name of the property.
 * @param value The value to set.
 */
- (void) reportFieldForProperty:(NSString*) propertyName setValue:(id) value;

/** Create a new sink. Subclasses must implement this.
 */
- (id<SentryCrashReportFilter>) sink;

/** Make an absolute key path if the specified path is not already absolute. */
- (NSString*) makeKeyPath:(NSString*) keyPath;

/** Make an absolute key paths from the specified paths. */
- (NSArray*) makeKeyPaths:(NSArray*) keyPaths;

@end
