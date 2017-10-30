//
//  MIKMIDIMappingXMLParser.h
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 4/15/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIKMIDICompilerCompatibility.h"

@class MIKMIDIMapping;

NS_ASSUME_NONNULL_BEGIN

/**
 *  A parser for XML MIDI mapping files. Only used on iOS. On OS X, NSXMLDocument is used
 *  directly instead. Should be considered "private" for use by MIKMIDIMapping.
 */
@interface MIKMIDIMappingXMLParser : NSObject

+ (instancetype)parserWithXMLData:(NSData *)xmlData;
- (instancetype)initWithXMLData:(NSData *)xmlData;

@property (nonatomic, strong, readonly) MIKArrayOf(MIKMIDIMapping *) *mappings;

@end

NS_ASSUME_NONNULL_END