//
//  F53OSCBundle.m
//
//  Created by Siobhán Dougall on 1/17/11.
//
//  Copyright (c) 2011-2020 Figure 53 LLC, https://figure53.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCBundle.h"

#import "F53OSCTimeTag.h"
#import "F53OSCFoundationAdditions.h"


NS_ASSUME_NONNULL_BEGIN

@implementation F53OSCBundle

+ (nullable F53OSCBundle *) bundleWithString:(NSString *)qscString
{
    NSLog( @"Error: F53OSCBundle does not yet support conversion of OSC bundles to/from a QSC form." );
    return nil;
}

+ (F53OSCBundle *) bundleWithTimeTag:(F53OSCTimeTag *)timeTag
                            elements:(NSArray<NSData *> *)elements
{
    F53OSCBundle *bundle = [F53OSCBundle new];
    bundle.timeTag = timeTag;
    bundle.elements = elements;
    return bundle;
}

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        self.timeTag = [F53OSCTimeTag immediateTimeTag];
        self.elements = [NSArray array];
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@", self.elements];
}

- (NSData *) packetData
{
    NSMutableData *result = [[@"#bundle" oscStringData] mutableCopy];
    
    [result appendData:[self.timeTag oscTimeTagData]];
    
    for ( NSData *element in self.elements )
    {
        if ( ![element isKindOfClass:[NSData class]] )
        {
            NSLog( @"Encountered an unknown bundle element of class %@. Bundles can only contain NSData elements. Skipping.", NSStringFromClass( [element class] ) );
            continue;
        }
        
        [result appendData:[element oscBlobData]];
    }
    
    return result;
}

- (nullable NSString *) asQSC
{
    NSLog( @"Error: F53OSCBundle does not yet support conversion of OSC bundles to/from a QSC form." );
    
    // Candidate idea, if we ever decide we want to do this:
    //
    // #bundleJSON_STRING
    //
    // e.g. #bundle{ "some_arbitrary_name": ["/a/message", "/another/message with arguments 1 2 \"3\"", "another_arbitrary_name": ["/internal/bundle/message"]] }
    
    return nil;
}

@end

NS_ASSUME_NONNULL_END
