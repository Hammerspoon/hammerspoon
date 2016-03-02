//
//  NSAppleEventDescriptor+Parsing
//  Hammerspoon
//
//  Created by Michael Bujol on 2/25/16.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//
//  Adapted from https://developer.apple.com/library/mac/samplecode/sc2280/Listings/SimpleAssetManagerSample_ScriptingSupportCategories_m.html
//

#import <Foundation/Foundation.h>

@interface NSDictionary (UserDefinedRecord)

// AppleEvent record descriptor (typeAERecord) with arbitrary keys
+(NSDictionary*)scriptingUserDefinedRecordWithDescriptor:(NSAppleEventDescriptor*)desc;

@end

@interface NSArray (UserList)

// AppleEvent list descriptor (typeAEList)
+(NSArray*)scriptingUserListWithDescriptor:(NSAppleEventDescriptor*)desc;

@end

@interface NSAppleEventDescriptor (GenericObject)

// AppleEvent descriptor that may be a record, a list, or other object
// This is necessary to handle a list or a record contained in another list or record
-(id)objectValue;

@end
