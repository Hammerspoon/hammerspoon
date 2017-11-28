//
//  MIKMIDIObject_SubclassMethods.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "MIKMIDIObject.h"
#import "MIKMIDICompilerCompatibility.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  These methods can be called and/or overridden by subclasses of MIKMIDIObject, but are not
 *  otherwise part of the public interface to MIKMIDIObject. They should not be called directly
 *  except by subclasses of MIKMIDIObject.
 */
@interface MIKMIDIObject ()

/**
 *  Registers a subclass of MIKMIDIObject. Registered subclasses will be instantiated and returned
 *  by -[MIKMIDIObject initWithObjectRef:] and +[MIKMIDIObject MIDIObjectWithObjectRef:] for
 *  the object type(s) they support.
 *
 *  Typically this method should be called in the subclass's +load method.
 *
 *  @note If two subclasses represent the same object type, as determined by calling +representedMIDIObjectTypes,
 *  which one is used is undefined.
 *
 *  @param subclass A subclass of MIKMIDIObject.
 */
+ (void)registerSubclass:(Class)subclass;

/**
 *  The MIDIObjectTypes the receiver can represent. MIKMIDIObject uses this method to determine which
 *  subclass to use to represent a particular MIDI object type.
 *
 *  @return An NSArray containing NSNumber representations of MIDIObjectType values.
 */
+ (MIKArrayOf(NSNumber *) *)representedMIDIObjectTypes;

/**
 *  Whether the receiver can be initialized with the passed in objectRef,
 *  which may be NULL (e.g. for purely virtual objects).
 *
 *  MIKMIDIObject's base implementation of this method checks the object's
 *  type and returns YES if it is contained in the array returned by +representedMIDIObjectTypes.
 *  Therefore, unless special behavior is required (e.g. supporting virtual objects
 *  where the objectRef is NULL), this does not typically need to be overriden.
 *
 *  @param objectRef A CoreMIDI MIDIObjectRef.
 *
 *  @return YES, if the class can be instantiated using the passed in object, NO otherwise.
 */
+ (BOOL)canInitWithObjectRef:(MIDIObjectRef)objectRef;

@property (nonatomic, readwrite) BOOL isVirtual;

@end

NS_ASSUME_NONNULL_END