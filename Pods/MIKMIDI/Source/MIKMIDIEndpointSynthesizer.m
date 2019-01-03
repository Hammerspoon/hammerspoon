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
#import "MIKMIDIPrivate.h"

#if !__has_feature(objc_arc)
#error MIKMIDIEndpointSynthesizer.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIEndpointSynthesizer.m in the Build Phases for this target
#endif

@interface MIKMIDIEndpointSynthesizer ()

@property (nonatomic, strong, readwrite) MIKMIDIEndpoint *endpoint;

@property (nonatomic, strong) id connectionToken;

@end

@implementation MIKMIDIEndpointSynthesizer

+ (instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source error:(NSError **)error
{
    return [[self alloc] initWithMIDISource:source error:error];
}

+ (instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source
                componentDescription:(AudioComponentDescription)componentDescription
                               error:(NSError **)error
{
    return [[self alloc] initWithMIDISource:source componentDescription:componentDescription error:error];
}

- (instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source error:(NSError **)error
{
    return [self initWithMIDISource:source componentDescription:[[self class] appleSynthComponentDescription] error:error];
}

- (instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source
              componentDescription:(AudioComponentDescription)componentDescription
                             error:(NSError **)error;
{
    self = [super initWithAudioUnitDescription:componentDescription error:error];
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
                                                   error:(NSError **)error
{
    return [self synthesizerWithClientDestinationEndpoint:destination
                                     componentDescription:[self appleSynthComponentDescription]
                                                    error:error];
}

+ (instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                    componentDescription:(AudioComponentDescription)componentDescription
                                                   error:(NSError **)error
{
    return [[self alloc] initWithClientDestinationEndpoint:destination
                                      componentDescription:componentDescription
             error:error];
}

- (instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                                            error:(NSError **)error
{
    return [self initWithClientDestinationEndpoint:destination
                              componentDescription:[[self class] appleSynthComponentDescription]
             error:error];
}

- (instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
                             componentDescription:(AudioComponentDescription)componentDescription
                                            error:(NSError **)error
{
    if (!destination) {
        [NSException raise:NSInvalidArgumentException format:@"%s requires a non-nil destination endpoint argument.", __PRETTY_FUNCTION__];
        return nil;
    }
    
    self = [super initWithAudioUnitDescription:componentDescription error:error];
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

#pragma mark - Deprecated

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

+ (instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self playerWithMIDISource:source error:NULL];
}

+ (instancetype)playerWithMIDISource:(MIKMIDISourceEndpoint *)source componentDescription:(AudioComponentDescription)componentDescription
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self playerWithMIDISource:source componentDescription:componentDescription error:NULL];
}

- (instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self initWithMIDISource:source error:NULL];
}

- (instancetype)initWithMIDISource:(MIKMIDISourceEndpoint *)source componentDescription:(AudioComponentDescription)componentDescription;
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self initWithMIDISource:source componentDescription:componentDescription error:NULL];
}

+ (instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self synthesizerWithClientDestinationEndpoint:destination error:NULL];
}

+ (instancetype)synthesizerWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination componentDescription:(AudioComponentDescription)componentDescription
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self synthesizerWithClientDestinationEndpoint:destination componentDescription:componentDescription error:NULL];
}

- (instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self initWithClientDestinationEndpoint:destination error:NULL];
}

- (instancetype)initWithClientDestinationEndpoint:(MIKMIDIClientDestinationEndpoint *)destination componentDescription:(AudioComponentDescription)componentDescription
{
    SHOW_STANDARD_DEPRECATION_WARNING;
    return [self initWithClientDestinationEndpoint:destination componentDescription:componentDescription error:NULL];
}

#pragma clang diagnostic pop

@end
