//
//  MIKMIDIErrors.m
//  Danceability
//
//  Created by Andrew Madsen on 7/19/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIErrors.h"

#if !__has_feature(objc_arc)
#error MIKMIDIErrors.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for MIKMIDIErrors.m in the Build Phases for this target
#endif

NSString * const MIKMIDIErrorDomain = @"MIKMIDIErrorDomain";

NSString *MIKMIDIDefaultLocalizedErrorDescriptionForErrorCode(MIKMIDIErrorCode code)
{
	NSDictionary *descriptions =
	@{@(MIKMIDIDeviceHasNoSourcesErrorCode) : NSLocalizedString(@"MIDI Device has no sources.", @"MIDI Device has no sources."),
	  @(MIKMIDIUnknownErrorCode) : NSLocalizedString(@"An unknown MIDI error occurred.", @"An unknown MIDI error occurred.")};
	return descriptions[@(code)] ?: NSLocalizedString(@"A MIDI error occurred.", @"Generic error description");
}

@implementation NSError (MIKMIDI)

+ (instancetype)MIKMIDIErrorWithCode:(MIKMIDIErrorCode)code userInfo:(NSDictionary *)userInfo;
{
	if (!userInfo) userInfo = @{};
	if (!userInfo[NSLocalizedDescriptionKey]) {
		NSMutableDictionary *scratch = [userInfo mutableCopy];
		scratch[NSLocalizedDescriptionKey] = MIKMIDIDefaultLocalizedErrorDescriptionForErrorCode(code);
		userInfo = scratch;
	}
	return [NSError errorWithDomain:MIKMIDIErrorDomain code:code userInfo:userInfo];
}

@end
