//
//  NSAppleEventDescriptor+Parsing.m
//  Hammerspoon
//
//  Created by Michael Bujol on 2/25/16.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "NSAppleEventDescriptor+Parsing.h"
#import <Carbon/Carbon.h>

@implementation NSDictionary (UserDefinedRecord)

+(NSDictionary*)scriptingUserDefinedRecordWithDescriptor:(NSAppleEventDescriptor*)desc {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:0];

    // keyASUserRecordFields has a list of alternating keys and values
    NSAppleEventDescriptor* userFieldItems = [desc descriptorForKeyword:keyASUserRecordFields];
    NSInteger numItems = [userFieldItems numberOfItems];

    for ( NSInteger itemIndex = 1; itemIndex <= numItems - 1; itemIndex += 2 ) {
        NSAppleEventDescriptor* keyDesc = [userFieldItems descriptorAtIndex:itemIndex];
        NSAppleEventDescriptor* valueDesc = [userFieldItems descriptorAtIndex:itemIndex + 1];

        // convert key and value to Foundation object
        // note the value can be another record or list
        NSString* keyString = [keyDesc stringValue];
        id value = [valueDesc objectValue];

        if ( keyString != nil && value != nil )
            [dict setObject:value forKey:keyString];
    }

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end

@implementation NSArray (UserList)

+(NSArray*)scriptingUserListWithDescriptor:(NSAppleEventDescriptor*)desc {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:0];
    NSInteger numItems = [desc numberOfItems];

    // for each item in the list, convert to Foundation object and add to the array
    for ( NSInteger itemIndex = 1; itemIndex <= numItems; itemIndex++ ) {
        NSAppleEventDescriptor* itemDesc = [desc descriptorAtIndex:itemIndex];
        id objectValue = [itemDesc objectValue];

        if (objectValue) {
            [array addObject:objectValue];
        }
    }

    return [NSArray arrayWithArray:array];
}

@end


@implementation NSAppleEventDescriptor (GenericObject)

-(id)objectValue {
    DescType    descType = [self descriptorType];
    id          object = nil;

    switch ( descType ) {
        case typeUnicodeText:
        case typeUTF8Text:
        case typeFileURL:
            object = [self stringValue];
            break;
        case typeTrue:
            object = [NSNumber numberWithBool:(BOOL)[self booleanValue]];
            break;
        case typeFalse:
            object = [NSNumber numberWithBool:(BOOL)[self booleanValue]];
            break;
        case typeAEList:
            object = [NSArray scriptingUserListWithDescriptor:self];
            break;
        case typeAERecord:
            object = [NSDictionary scriptingUserDefinedRecordWithDescriptor:self];
            break;
        case typeSInt16:
        case typeUInt16:
        case typeSInt32:
        case typeUInt32:
        case typeSInt64:
        case typeUInt64:
            object = [NSNumber numberWithInteger:(NSInteger)[self int32Value]];
            break;
        case typeIEEE32BitFloatingPoint:
        case typeIEEE64BitFloatingPoint:
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            object = [NSNumber numberWithDouble:(double)[self doubleValue]];
#pragma clang diagnostic pop
            break;
        case typeNull:
        case typeType:
            object = [NSNull null];
            break;
        default:
            object = [self stringValue];
            break;
    }

    if (!object) {
        // FIXME: Do better logging here
        NSLog(@"ERROR: NSAppleEventDescriptor objectValue is nil. Given descriptorType is: %d", descType);
    }

    return object;
}

@end
