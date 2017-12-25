//
//  MIKMIDIMetaEvent_SubclassMethods.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/10/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import "MIKMIDIMetaEvent.h"
#import "MIKMIDIEvent_SubclassMethods.h"

@interface MIKMIDIMetaEvent ()

/**
 *  Initializes a new MIKMIDIMetaEvent subclass with the specified data, inferring
 *  the meta data type using +supportedMIDIEventTypes. Only meant to be used internally
 *  to more easily implement custom initializers.
 *
 *  @param metaData     An NSData containing the metadata for the event.
 *  on this value. If this value is invalid or unknown, a plain MIKMIDIMetaEvent instance will be returned.
 *  @param timeStamp    The MusicTimeStamp timestamp for the event.
 *
 *  @return An initialized instance of MIKMIDIMetaEvent or one of its subclasses.
 */
- (instancetype)initWithMetaData:(NSData *)metaData timeStamp:(MusicTimeStamp)timeStamp;

@property (nonatomic, strong, readwrite) NSData *metaData;

@end
