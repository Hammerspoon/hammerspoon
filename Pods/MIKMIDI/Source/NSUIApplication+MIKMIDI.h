//
//  NSApplication+MIKMIDI.h
//  Energetic
//
//  Created by Andrew Madsen on 3/11/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>
#define MIK_APPLICATION_CLASS UIApplication
#define MIK_WINDOW_CLASS UIWindow
#define MIK_VIEW_CLASS UIView

#else

#import <Cocoa/Cocoa.h>
#define MIK_APPLICATION_CLASS NSApplication
#define MIK_WINDOW_CLASS NSWindow
#define MIK_VIEW_CLASS NSView

#endif

#import "MIKMIDICompilerCompatibility.h"

/**
 *  Define MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS as a non-zero value to (re)enable searching
 *  the view hierarchy for MIDI responders. This is disabled by default because it's slow.
 *
 *  @deprecated This feature still works, but its use is discouraged. It is deprecated and may be removed in the future.
 */
//#define MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS 0

@protocol MIKMIDIResponder;

@class MIKMIDICommand;

NS_ASSUME_NONNULL_BEGIN

/**
 *  MIKMIDI implements a category on NSApplication (on OS X) or UIApplication (on iOS)
 *  to facilitate the creation and use of a MIDI responder hierarchy, along with the ability
 *  to send MIDI commands to responders in that hierarchy.
 */
@interface MIK_APPLICATION_CLASS (MIKMIDI)

/**
 *  Register a MIDI responder for receipt of incoming MIDI messages.
 *
 *  If targeting OS X 10.8 or higher, or iOS, the application maintains a zeroing weak
 *  reference to the responder, so unregistering the responder on deallocate is not necessary.
 *
 *  For applications targeting OS X 10.7, registered responders must be explicitly
 *  unregistered (e.g. in their -dealloc method) by calling -unregisterMIDIResponder before
 *  being deallocated.
 *
 *  @param responder The responder to register.
 */
- (void)registerMIDIResponder:(id<MIKMIDIResponder>)responder;

/**
 *  Unregister a previously-registered MIDI responder so it stops receiving incoming MIDI messages.
 *
 *  @param responder The responder to unregister.
 */
- (void)unregisterMIDIResponder:(id<MIKMIDIResponder>)responder;

/**
 *  When subresponder caching is enabled via shouldCacheMIKMIDISubresponders,
 *  This method will cause the cache to be invalidated and regenerated. If a previously
 *  registered MIDI responders' subresponders have changed, it can call this method
 *  to force the cache to be refreshed.
 *
 *  If subresponder caching is disabled (the default), calling this method has no effect, as
 *  subresponders are dynamically searched on every call to -MIDIResponderWithIdentifier and
 *  -allMIDIResponders.
 *
 *  @see shouldCacheMIKMIDISubresponders
 */
- (void)refreshMIDIRespondersAndSubresponders;

/**
 *  NSApplication (OS X) or UIApplication (iOS) itself implements to methods in the MIKMIDIResponder protocol.
 *  This method determines if any responder in the MIDI responder chain (registered responders and their subresponders)
 *  responds to the passed in MIDI command, and returns YES if so.
 *
 *  @param command An MIKMIDICommand instance.
 *
 *  @return YES if any registered MIDI responder responds to the command.
 */
- (BOOL)respondsToMIDICommand:(MIKMIDICommand *)command;

/**
 *  When this method is invoked with a MIDI command, the application will search its registered MIDI responders,
 *  for responders that respond to the command, then call their -handleMIDICommand: method.
 *
 *  Call this method from a MIDI source event handler block to automatically dispatch MIDI commands/messages
 *  from that source to all interested registered responders.
 *
 *  @param command The command to dispatch to responders.
 */
- (void)handleMIDICommand:(MIKMIDICommand *)command;

/**
 *  Returns a registered MIDI responder with the given MIDI identifier.
 *
 *  @param identifier An NSString instance containing the MIDI identifier to search for.
 *
 *  @return An object that conforms to MIKMIDIResponder, or nil if no registered responder for the passed in identifier
 *  could be found.
 */
- (nullable id<MIKMIDIResponder>)MIDIResponderWithIdentifier:(NSString *)identifier;

/**
 *  Returns all MIDI responders that have been registered with the application.
 *
 *  @return An NSSet containing objects that conform to the MIKMIDIResponder protocol.
 */
- (MIKSetOf(id<MIKMIDIResponder>) *)allMIDIResponders;

// Properties

/**
 *  When this option is set, the application will cache registered MIDI responders' subresponders.
 *  Setting this option can greatly improve performance of -MIDIResponderWithIdentifier. However,
 *  when set, registered responders' -subresponders method cannot dynamically return different results
 *  e.g. for each MIDI command received.
 *
 *  The entire cache is automatically refreshed anytime a new MIDI responder is registered or unregistered.
 *  It can also be manually refreshed by calling -refreshRespondersAndSubresponders.
 *
 *  For backwards compatibility the default for this option is NO, or no caching.
 *
 *  @see -refreshRespondersAndSubresponders
 */
@property (nonatomic) BOOL shouldCacheMIKMIDISubresponders;

@end

NS_ASSUME_NONNULL_END