//
//  NSApplication+MIKMIDI.m
//  Energetic
//
//  Created by Andrew Madsen on 3/11/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import "NSUIApplication+MIKMIDI.h"
#import "MIKMIDIResponder.h"
#import "MIKMIDICommand.h"
#import <objc/runtime.h>

#if !__has_feature(objc_arc)
#error NSApplication+MIKMIDI.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for NSApplication+MIKMIDI.m in the Build Phases for this target
#endif

#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS

@interface MIK_VIEW_CLASS (MIKSubviews)
- (NSSet *)mik_allSubviews; // returns all subviews in flat set
@end

@implementation MIK_VIEW_CLASS (MIKSubviews)

- (NSSet *)mik_allSubviews
{
	NSMutableSet *result = [NSMutableSet setWithArray:[self subviews]];
	for (MIK_VIEW_CLASS *subview in [self subviews]) {
		[result unionSet:[subview mik_allSubviews]];
	}
	return result;
}

@end

#endif

static BOOL MIKObjectRespondsToMIDICommand(id object, MIKMIDICommand *command)
{
	if (!object) return NO;
	return [object conformsToProtocol:@protocol(MIKMIDIResponder)] && [(id<MIKMIDIResponder>)object respondsToMIDICommand:command];
}

@interface MIKMIDIResponderHierarchyManager : NSObject

// Public
- (void)refreshRespondersAndSubresponders;
- (id<MIKMIDIResponder>)MIDIResponderWithIdentifier:(NSString *)identifier;

// Properties
@property (nonatomic, strong) NSHashTable *registeredMIKMIDIResponders;
@property (nonatomic, strong, readonly) NSSet *registeredMIKMIDIRespondersAndSubresponders;

@property (nonatomic, strong) NSHashTable *subrespondersCache;

@property (nonatomic) BOOL shouldCacheMIKMIDISubresponders;

@property (nonatomic, strong, readonly) NSSet *allMIDIResponders;

@property (nonatomic, strong, readonly) NSPredicate *midiIdentifierPredicate;

@end

@implementation MIKMIDIResponderHierarchyManager

+ (NSPointerFunctionsOptions)hashTableOptions
{
#if TARGET_OS_IPHONE
	return NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality;
#elif (MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_7)
	return NSPointerFunctionsZeroingWeakMemory | NSPointerFunctionsObjectPersonality;
#else
	return NSHashTableWeakMemory | NSPointerFunctionsObjectPersonality;
#endif
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		NSPointerFunctionsOptions options = [[self class] hashTableOptions];
		_registeredMIKMIDIResponders = [[NSHashTable alloc] initWithOptions:options capacity:0];

		_shouldCacheMIKMIDISubresponders = NO;
	}
	return self;
}

- (void)registerMIDIResponder:(id<MIKMIDIResponder>)responder;
{
	[self.registeredMIKMIDIResponders addObject:responder];
	[self refreshRespondersAndSubresponders];
}

- (void)unregisterMIDIResponder:(id<MIKMIDIResponder>)responder;
{
	[self.registeredMIKMIDIResponders removeObject:responder];
	[self refreshRespondersAndSubresponders];
}

#pragma mark - Public

- (void)refreshRespondersAndSubresponders
{
	self.subrespondersCache = nil;
}

- (id<MIKMIDIResponder>)MIDIResponderWithIdentifier:(NSString *)identifier
{
	NSSet *registeredResponders = self.registeredMIKMIDIRespondersAndSubresponders;
	
	id<MIKMIDIResponder> result = nil;
	for (id<MIKMIDIResponder> responder in registeredResponders) {
		if ([[responder MIDIIdentifier] isEqualToString:identifier]) {
			result = responder;
			break;
		}
	}
	
#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS
	if (!result) {
		NSMutableSet *viewHierarchyResponders = [[self MIDIRespondersInViewHierarchy] mutableCopy];
		[viewHierarchyResponders minusSet:registeredResponders];
		result = [[viewHierarchyResponders filteredSetUsingPredicate:predicate] anyObject];
		
		if (result) {
			NSLog(@"WARNING: Found responder %@ for identifier %@ by traversing view hierarchy. This path for finding MIDI responders is deprecated. Responders should be explicitly registered with NS/UIApplication.", result, identifier);
		}
	}
#endif
	return result;
}

#pragma mark - Private

- (NSSet *)recursiveSubrespondersOfMIDIResponder:(id<MIKMIDIResponder>)responder
{
	NSMutableSet *result = [NSMutableSet setWithObject:responder];
	if (![responder respondsToSelector:@selector(subresponders)]) return result;
	
	NSArray *subresponders = [responder subresponders];
	[result addObjectsFromArray:subresponders];
	for (id<MIKMIDIResponder>subresponder in subresponders) {
		[result unionSet:[self recursiveSubrespondersOfMIDIResponder:subresponder]];
	}
	
	return result;
}

#pragma mark - Properties

- (NSSet *)registeredMIKMIDIRespondersAndSubresponders
{
	if (self.shouldCacheMIKMIDISubresponders && self.subrespondersCache != nil) {
		return [self.subrespondersCache setRepresentation];
	}
	
	NSMutableSet *result = [NSMutableSet set];
	for (id<MIKMIDIResponder> responder in self.registeredMIKMIDIResponders) {
		[result unionSet:[self recursiveSubrespondersOfMIDIResponder:responder]];
	}
	
#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS
	[result unionSet:[self MIDIRespondersInViewHierarchy]];
#endif

	if (self.shouldCacheMIKMIDISubresponders) {
		// Load cache with result
		NSPointerFunctionsOptions options = [[self class] hashTableOptions];
		self.subrespondersCache = [[NSHashTable alloc] initWithOptions:options capacity:0];
		for (id object in result) { [self.subrespondersCache addObject:object]; }
	}
	
	return [result copy];
}

+ (NSSet *)keyPathsForValuesAffectingAllMIDIResponders
{
	return [NSSet setWithObjects:@"registeredMIKMIDIRespondersAndSubresponders", nil];
}

- (NSSet *)allMIDIResponders
{
	return self.registeredMIKMIDIRespondersAndSubresponders;
}

@synthesize midiIdentifierPredicate = _midiIdentifierPredicate;
- (NSPredicate *)midiIdentifierPredicate
{
	if (!_midiIdentifierPredicate) {
		_midiIdentifierPredicate = [NSPredicate predicateWithFormat:@"MIDIIdentifier LIKE $MIDIIdentifier"];
	}
	return _midiIdentifierPredicate;
}

#pragma mark - Deprecated

#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS
- (NSSet *)MIDIRespondersInViewHierarchy
{
	NSMutableSet *result = [NSMutableSet set];
	
	// Go through the entire view hierarchy
	for (MIK_WINDOW_CLASS *window in [[MIK_APPLICATION_CLASS sharedApplication] windows]) {
		if ([window conformsToProtocol:@protocol(MIKMIDIResponder)]) {
			[result unionSet:[self recursiveSubrespondersOfMIDIResponder:(id<MIKMIDIResponder>)window]];
		}
#if !TARGET_OS_IPHONE
		if ([[window delegate] conformsToProtocol:@protocol(MIKMIDIResponder)]) {
			[result unionSet:[self recursiveSubrespondersOfMIDIResponder:(id<MIKMIDIResponder>)[window delegate]]];
		}
		if ([[window windowController] conformsToProtocol:@protocol(MIKMIDIResponder)]) {
			[result unionSet:[self recursiveSubrespondersOfMIDIResponder:[window windowController]]];
		}
		NSSet *allSubviews = [[window contentView] mik_allSubviews];
#else
		NSSet *allSubviews = [window.rootViewController.view mik_allSubviews];
#endif
		for (MIK_VIEW_CLASS *subview in allSubviews) {
			if ([subview conformsToProtocol:@protocol(MIKMIDIResponder)]) {
				[result unionSet:[self recursiveSubrespondersOfMIDIResponder:(id<MIKMIDIResponder>)subview]];
			}
		}
	}
	
	return result;
}

#endif // MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS

@end

#pragma mark -

@implementation MIK_APPLICATION_CLASS (MIKMIDI)

- (void)registerMIDIResponder:(id<MIKMIDIResponder>)responder; { [self.mikmidi_responderHierarchyManager registerMIDIResponder:responder]; }

- (void)unregisterMIDIResponder:(id<MIKMIDIResponder>)responder; { [self.mikmidi_responderHierarchyManager unregisterMIDIResponder:responder]; }

- (BOOL)respondsToMIDICommand:(MIKMIDICommand *)command;
{
	MIKMIDIResponderHierarchyManager *manager = self.mikmidi_responderHierarchyManager;
	
	NSSet *registeredResponders = [self respondersForCommand:command inResponders:manager.allMIDIResponders];
	if ([registeredResponders count]) return YES;
	
#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS
	NSSet *viewHierarchyResponders = [self respondersForCommand:command inResponders:[self MIDIRespondersInViewHierarchy]];
	return ([viewHierarchyResponders count] != 0);
#endif
	return NO;
}

- (void)handleMIDICommand:(MIKMIDICommand *)command;
{
	MIKMIDIResponderHierarchyManager *manager = self.mikmidi_responderHierarchyManager;
	NSSet *registeredResponders = [self respondersForCommand:command inResponders:manager.allMIDIResponders];
	for (id<MIKMIDIResponder> responder in registeredResponders) {
		[responder handleMIDICommand:command];
	}
	
#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS
	NSMutableSet *viewHierarchyResponders = [[self respondersForCommand:command inResponders:[self MIDIRespondersInViewHierarchy]] mutableCopy];
	[viewHierarchyResponders minusSet:registeredResponders];
	
	for (id<MIKMIDIResponder> responder in viewHierarchyResponders) {
		NSLog(@"WARNING: Found responder %@ for command %@ by traversing view hierarchy. This path for finding MIDI responders is deprecated. Responders should be explicitly registered with NS/UIApplication.", responder, command);
		[responder handleMIDICommand:command];
	}
#endif
}

- (id<MIKMIDIResponder>)MIDIResponderWithIdentifier:(NSString *)identifier;
{
	return [self.mikmidi_responderHierarchyManager MIDIResponderWithIdentifier:identifier];
}

- (NSSet *)allMIDIResponders { return [self.mikmidi_responderHierarchyManager allMIDIResponders]; }
- (void)refreshMIDIRespondersAndSubresponders { [self.mikmidi_responderHierarchyManager refreshRespondersAndSubresponders]; }

#pragma mark - Private

- (NSSet *)respondersForCommand:(MIKMIDICommand *)command inResponders:(NSSet *)responders
{
	return [responders filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<MIKMIDIResponder>responder, NSDictionary *bindings) {
		return MIKObjectRespondsToMIDICommand(responder, command);
	}]];
}

#pragma mark - Properties

- (MIKMIDIResponderHierarchyManager *)mikmidi_responderHierarchyManager
{
	static MIKMIDIResponderHierarchyManager *manager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		manager = [[MIKMIDIResponderHierarchyManager alloc] init];
	});
	return manager;
}

+ (NSSet *)keyPathsForValuesAffectingShouldCacheMIKMIDISubresponders
{
	return [NSSet setWithObject:@"mikmidi_responderHierarchyManager.shouldCacheMIKMIDISubresponders"];
}
- (BOOL)shouldCacheMIKMIDISubresponders { return [self.mikmidi_responderHierarchyManager shouldCacheMIKMIDISubresponders]; }
- (void)setShouldCacheMIKMIDISubresponders:(BOOL)flag { [self.mikmidi_responderHierarchyManager setShouldCacheMIKMIDISubresponders:flag]; }

#pragma mark - Deprecated

#if MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS
- (NSSet *)MIDIRespondersInViewHierarchy { return [self.mikmidi_responderHierarchyManager MIDIRespondersInViewHierarchy]; }
#endif // MIKMIDI_SEARCH_VIEW_HIERARCHY_FOR_RESPONDERS

@end
