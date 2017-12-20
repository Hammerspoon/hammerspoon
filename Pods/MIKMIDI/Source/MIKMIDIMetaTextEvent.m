//
//  MIKMIDIMetadataTextEvent.m
//  MIDI Files Testbed
//
//  Created by Jake Gundersen on 5/22/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaTextEvent.h"
#import "MIKMIDIMetaEvent_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIMetaTextEvent.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIMetaTextEvent.m in the Build Phases for this target
#endif

@implementation MIKMIDIMetaTextEvent

+ (void)load { [MIKMIDIEvent registerSubclass:self]; }
+ (NSArray *)supportedMIDIEventTypes { return @[@(MIKMIDIEventTypeMetaText)]; }
+ (Class)immutableCounterpartClass { return [MIKMIDIMetaTextEvent class]; }
+ (Class)mutableCounterpartClass { return [MIKMutableMIDIMetaTextEvent class]; }
+ (BOOL)isMutable { return NO; }

- (instancetype)initWithString:(NSString *)string timeStamp:(MusicTimeStamp)timeStamp
{
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	return [self initWithMetaData:data timeStamp:timeStamp];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"string"]) {
        [keyPaths setByAddingObject:@"metaData"];
    }
    return keyPaths;
}

- (NSString *)string
{
	if (![self.metaData length]) return nil;
    return [[NSString alloc] initWithData:self.metaData encoding:NSUTF8StringEncoding];
}

- (void)setString:(NSString *)string
{
    if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
    [self setMetaData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString *)additionalEventDescription
{
    return [NSString stringWithFormat:@"Metadata Type: 0x%02x, String: %@", self.metadataType, self.string];
}

@end

@implementation MIKMutableMIDIMetaTextEvent

@dynamic timeStamp;
@dynamic metadataType;
@dynamic metaData;
@dynamic string;

+ (BOOL)isMutable { return YES; }

@end