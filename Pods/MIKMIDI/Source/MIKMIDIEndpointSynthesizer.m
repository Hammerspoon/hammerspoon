//
//  MIKMIDIEndpointSynthesizer.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 5/27/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKMIDIEndpointSynthesizer.h"
#import <AudioToolbox/AudioToolbox.h>
#import "MIKMIDI.h"
#import "MIKMIDIClientDestinationEndpoint.h"

#if !__has_feature(objc_arc)
#error MIKMIDIEndpointSynthesizer.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIEndpointSynthesizer.m in the Build Phases for this target
#endif

@interface MIKMIDIEndpointSynthesizer ()

@property (nonatomic, strong, readwrite) MIKMIDIEndpoint *endpoint;

@property (nonatomic, strong) id connectionToken;

@end

@implementation MIKMIDIEndpointSynthesizer

+ (instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source
{
	return [[self alloc] initWithMIDISource:source];
}

+ (instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source componentDescription:(AudioComponentDescription)componentDescription
{
	return [[self alloc] initWithMIDISource:source componentDescription:componentDescription];
}

- (instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source
{
	return [self initWithMIDISource:source componentDescription:[[self class] appleSynthComponentDescription]];
}

- (instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source componentDescription:(AudioComponentDescription)componentDescription;
{
	self = [super initWithAudioUnitDescription:componentDescription];
	if (self) {
		if (source) {
			NSError *error = nil;
			if (![self connectToMIDISource:source error:&error]) {
				NSLog(@"Unable to connect to MIDI source %@: %@", source, error);
				return nil;
			}
			_endpoint = source;
		}
	}
	return self;
}

+ (instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
{
	return [self synthesizerWithClientDestinationEndpoint:destination componentDescription:[self appleSynthComponentDescription]];
}

+ (instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination componentDescription:(AudioComponentDescription)componentDescription
{
	return [[self alloc] initWithClientDestinationEndpoint:destination componentDescription:componentDescription];
}

- (instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
{
	return [self initWithClientDestinationEndpoint:destination componentDescription:[[self class] appleSynthComponentDescription]];
}

- (instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination componentDescription:(AudioComponentDescription)componentDescription
{
	if (!destination) {
		[NSException raise:NSInvalidArgumentException format:@"%s requires a non-nil destination endpoint argument.", __PRETTY_FUNCTION__];
		return nil;
	}
	
	self = [super initWithAudioUnitDescription:componentDescription];
	if (self) {
		
		__weak MIKMIDIEndpointSynthesizer *weakSelf = self;
		destination.receivedMessagesHandler = ^(MIKMIDIClientDestinationEndpoint *destination, NSArray *commands){
			__strong MIKMIDIEndpointSynthesizer *strongSelf = weakSelf;
			[strongSelf handleMIDIMessages:commands];
		};
		_endpoint = destination;
	}
	return self;
}

- (void)dealloc
{
	if ([_endpoint isKindOfClass:[MIKMIDISourceEndpoint class]]) {
		[[MIKMIDIDeviceManager sharedDeviceManager] disconnectConnectionForToken:self.connectionToken];
	}
	// Don't need to do anything for a destination endpoint. __weak reference in the messages handler will automatically nil out.
}

#pragma mark - Private

- (BOOL)connectToMIDISource:(MIKMIDISourceEndpoint *)source error:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	
	__weak MIKMIDIEndpointSynthesizer *weakSelf = self;
	MIKMIDIDeviceManager *deviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
	id connectionToken = [deviceManager connectInput:source error:error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
		__strong MIKMIDIEndpointSynthesizer *strongSelf = weakSelf;
		[strongSelf handleMIDIMessages:commands];
	}];
	
	if (!connectionToken) return NO;
	
	self.endpoint = source;
	self.connectionToken = connectionToken;
	return YES;
}

@end
