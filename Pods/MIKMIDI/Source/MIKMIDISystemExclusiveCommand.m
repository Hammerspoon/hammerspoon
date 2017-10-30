//
//  MIKMIDISystemExclusiveCommand.m
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDISystemExclusiveCommand.h"
#import "MIKMIDICommand_SubclassMethods.h"
#import "MIKMIDIUtilities.h"

#if !__has_feature(objc_arc)
#error MIKMIDISystemExclusiveCommand.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDISystemExclusiveCommand.m in the Build Phases for this target
#endif

@interface MIKMIDISystemExclusiveCommand ()

@property (nonatomic, readwrite) UInt32 manufacturerID;
@property (nonatomic, readwrite) UInt8 sysexChannel;
@property (nonatomic, strong, readwrite) NSData *sysexData;

@end

@implementation MIKMIDISystemExclusiveCommand
{
	BOOL _has3ByteManufacturerID;
}

+ (void)load { [super load]; [MIKMIDICommand registerSubclass:self]; }
+ (NSArray *)supportedMIDICommandTypes { return @[@(MIKMIDICommandTypeSystemExclusive)]; }
+ (Class)immutableCounterpartClass; { return [MIKMIDISystemExclusiveCommand class]; }
+ (Class)mutableCounterpartClass; { return [MIKMutableMIDISystemExclusiveCommand class]; }

#pragma mark - Specialized Instances

+ (instancetype)identityRequestCommand
{
    MIKMutableMIDISystemExclusiveCommand *identityRequest = [[self mutableCounterpartClass] commandForCommandType:MIKMIDICommandTypeSystemExclusive];
	identityRequest.manufacturerID = kMIKMIDISysexNonRealtimeManufacturerID;
	identityRequest.sysexChannel = kMIKMIDISysexChannelDisregard;
	identityRequest.sysexData = [NSData dataWithBytes:(UInt8[]){0x06, 0x01} length:2];
    return identityRequest;
}

#pragma mark - Private

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *result = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"sysexData"]
        || [key isEqualToString:@"sysexChannel"]
        || [key isEqualToString:@"manufacturerID"]) {
		result = [result setByAddingObject:@"internalData"];
	}
	
	return result;
}

- (id)initWithMIDIPacket:(MIDIPacket *)packet
{
    self = [super initWithMIDIPacket:packet];
    if (self) {
        if ([self.internalData length] > 1) {
            UInt8 firstByte = self.dataByte1;
            if (firstByte == 0) {
                _has3ByteManufacturerID = YES;
				if ([self.internalData length] < 4) [self.internalData increaseLengthBy:4-[self.internalData length]];
            }
        }
    }
    return self;
}

- (UInt32)manufacturerID
{
    if ([self.internalData length] < 2) return 0;
    
    NSUInteger manufacturerIDLocation = _has3ByteManufacturerID ? 2 : 1;
    NSUInteger manufacturerIDLength = _has3ByteManufacturerID ? 2 : 1;
    NSData *idData = [self.internalData subdataWithRange:NSMakeRange(manufacturerIDLocation, manufacturerIDLength)];
    return *(UInt32 *)[idData bytes];
}

- (void)setManufacturerID:(UInt32)manufacturerID
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	NSUInteger numExistingBytes = _has3ByteManufacturerID ? 3 : 1;
	NSUInteger numNewBytes = (manufacturerID & 0xFFFF00) != 0 ? 3 : 1;
	UInt8 manufacturerIDBytes[3] = {(manufacturerID >> 2) & 0x7F, (manufacturerID >> 1) & 0x7F, manufacturerID & 0x7F};
	NSUInteger numRequiredBytes = MAX(numExistingBytes, numNewBytes) + 1;
	if ([self.internalData length] < numRequiredBytes) [self.internalData increaseLengthBy:numRequiredBytes-[self.internalData length]];
	
	UInt8 *replacementBytes = manufacturerIDBytes + 3 - numNewBytes;
	[self.internalData replaceBytesInRange:NSMakeRange(1, numExistingBytes) withBytes:replacementBytes length:numNewBytes];
	
	_has3ByteManufacturerID = (numNewBytes == 3);
}

- (BOOL)isUniversal
{
    UInt8 firstByte = self.dataByte1;
    return (firstByte == kMIKMIDISysexRealtimeManufacturerID
            || firstByte == kMIKMIDISysexNonRealtimeManufacturerID);
}

- (UInt8)sysexChannel
{
	if ([self.internalData length] < 3 || !self.isUniversal) return 0;
	
	NSData *sysexChannelData = [self.internalData subdataWithRange:NSMakeRange(2, 1)];
	return *(UInt8 *)[sysexChannelData bytes];
}

- (void)setSysexChannel:(UInt8)sysexChannel
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	NSUInteger sysexChannelLocation = _has3ByteManufacturerID ? 4 : 2;
	NSUInteger requiredLength = sysexChannelLocation+1;
	[self.internalData setLength:requiredLength];
	
	[self.internalData replaceBytesInRange:NSMakeRange(sysexChannelLocation, 1) withBytes:&sysexChannel length:1];
}

- (NSUInteger)sysexDataStartLocation
{
    NSUInteger sysexStartLocation = _has3ByteManufacturerID ? 4 : 2;
    if (self.isUniversal) {
        sysexStartLocation++;
    }
    return sysexStartLocation;
}

- (NSData *)sysexData
{
	NSUInteger sysexStartLocation = [self sysexDataStartLocation];
	return [self.internalData subdataWithRange:NSMakeRange(sysexStartLocation, [self.internalData length]-sysexStartLocation-1)];
}

- (void)setSysexData:(NSData *)sysexData
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	NSUInteger sysexStartLocation = [self sysexDataStartLocation];
	
	NSRange destinationRange = NSMakeRange(sysexStartLocation, [self.internalData length] - sysexStartLocation);
	[self.internalData replaceBytesInRange:destinationRange withBytes:[sysexData bytes] length:[sysexData length]];
}

- (NSData *)data
{
	NSMutableData *result = [[super data] mutableCopy];
    
    UInt8 lastByte;
    [result getBytes:&lastByte range:NSMakeRange([result length]-1, 1)];
    if (lastByte != kMIKMIDISysexEndDelimiter) {
        [result appendBytes:&(UInt8){kMIKMIDISysexEndDelimiter} length:1];
    }
	return result;
}

- (void)setData:(NSData *)data
{
	if (![[self class] isMutable]) return MIKMIDI_RAISE_MUTATION_ATTEMPT_EXCEPTION;
	
	if (![data length]) return [self setInternalData:[data mutableCopy]];
	
	UInt8 *bytes = (UInt8 *)[data bytes];
	UInt8 lastByte = bytes[[data length]-1];
	if (lastByte == kMIKMIDISysexEndDelimiter) {
		data = [data subdataWithRange:NSMakeRange(0, [data length]-1)];
	}
	
	self.internalData = [data mutableCopy];
}

- (NSString *)additionalCommandDescription
{
    return [NSString stringWithFormat:@"universal: %@ sysexChannel: %u", @(self.isUniversal), self.sysexChannel];
}

@end

@implementation MIKMutableMIDISystemExclusiveCommand

+ (BOOL)isMutable { return YES; }

#pragma mark - Properties

// One of the super classes already implements a getter *and* setter for these. @dynamic keeps the compiler happy.
@dynamic manufacturerID;
@dynamic sysexChannel;
@dynamic sysexData;
@dynamic timestamp;
@dynamic commandType;
@dynamic dataByte1;
@dynamic dataByte2;
@dynamic midiTimestamp;
@dynamic data;

@end
