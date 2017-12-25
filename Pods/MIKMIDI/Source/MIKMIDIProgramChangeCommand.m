//
//  MIKMIDIProgramChangeCommand.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 1/14/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIProgramChangeCommand.h"
#import "MIKMIDIChannelVoiceCommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDIControlChangeCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIControlChangeCommand.m in the Build Phases for this target
#endif

@interface MIKMIDIProgramChangeCommand ()

@property (nonatomic, readwrite) NSUInteger programNumber;

@end

@implementation MIKMIDIProgramChangeCommand

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeProgramChange)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDIProgramChangeCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDIProgramChangeCommand class]; }

- (NSString *)additionalCommandDescription
{
	return [NSString stringWithFormat:@"%@ program number: %lu", [super additionalCommandDescription], (unsigned long)self.programNumber];
}

#pragma mark - Private

#pragma mark - Properties

- (NSUInteger)programNumber { return self.dataByte1; }

- (void)setProgramNumber:(NSUInteger)value
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	self.dataByte1 = (UInt8)value;
}

@dynamic channel; // MIKMIDIChannelVoiceCommand already implements a getter *and* setter for this. This keeps the compiler happy.

@end

@implementation MIKMutableMIDIProgramChangeCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

// One of the super classes already implements a getter *and* setter for these. @dynamic keeps the compiler happy.
@dynamic channel;
@dynamic value;
@dynamic programNumber;

@end