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

        [array addObject:[itemDesc objectValue]];
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
            object = [NSNumber numberWithDouble:(double)[self doubleValue]];
            break;
        case typeNull:
        case typeType:
            object = [NSNull null];
            break;
        default:
            object = [self stringValue];
            break;
    }

    return object;
}

@end
