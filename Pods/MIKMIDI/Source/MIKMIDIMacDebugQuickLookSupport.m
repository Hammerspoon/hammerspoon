//
//  MIKMIDIDebugQuickLookSupport.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 4/1/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#if !TARGET_OS_IPHONE

#import "MIKMIDI.h"

#define kMIKMIDITrackDebugViewFrameRect (NSMakeRect(0, 0, 900, 500))

@interface MIKMIDITrackDebugView : NSView

- (instancetype)initWithTrack:(MIKMIDITrack *)track;
@property (nonatomic, strong, readonly) MIKMIDITrack *track;
@property (nonatomic, strong) NSColor *noteColor;

@end

@implementation MIKMIDITrackDebugView

- (instancetype)initWithTrack:(MIKMIDITrack *)track
{
	self = [super initWithFrame:kMIKMIDITrackDebugViewFrameRect];
	if (self) {
		_track = track;
		_noteColor = [[NSColor blueColor] colorWithAlphaComponent:0.5];
	}
	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	CGFloat eventHeight = NSHeight([self bounds]) / 128.0;
	MusicTimeStamp trackLength = self.track.length ?: 16;
	CGFloat ppt = NSWidth([self bounds]) / trackLength;
	
	for (MIKMIDINoteEvent *event in self.track.events) {
		NSColor *eventColor = nil;
		NSRect eventRect = NSZeroRect;

		if (event.eventType == kMusicEventType_MIDINoteMessage) {
			eventColor = self.noteColor;
			CGFloat yPosition = NSMinY([self bounds]) + (event.note + 1) * eventHeight;
			eventRect = NSMakeRect(NSMinX([self bounds]) + event.timeStamp * ppt, yPosition, event.duration * ppt, eventHeight);
		} else {
			eventColor = [NSColor darkGrayColor];
			eventRect = NSMakeRect(NSMinX([self bounds]) + event.timeStamp * ppt, NSMinY([self bounds]), ppt, eventHeight);
		}
		
//		[[NSColor blackColor] setStroke];
//		[eventColor setFill];
		[eventColor set];
		
		NSBezierPath *path = [NSBezierPath bezierPathWithRect:eventRect];
		[path fill];
		[path stroke];
	}
}

@end

@interface MIKMIDITrack (DebugQuickLook)

@end

@implementation MIKMIDITrack (DebugQuickLook)

- (id)debugQuickLookObject
{
	return [[MIKMIDITrackDebugView alloc] initWithTrack:self];
}

@end

@interface MIKMIDISequence (DebugQuickLook)

@end

@implementation MIKMIDISequence (DebugQuickLook)

- (id)debugQuickLookObject
{
	NSView *container = [[NSView alloc] initWithFrame:kMIKMIDITrackDebugViewFrameRect];
	NSArray *tracks = self.tracks;
	for (NSUInteger i=0; i<[tracks count]; i++) {
		MIKMIDITrackDebugView *trackView = [tracks[i] debugQuickLookObject];
		trackView.noteColor = [self colorForTrackAtIndex:i];
		[container addSubview:trackView];
	}
	return container;
}

- (NSColor *)colorForTrackAtIndex:(NSInteger)index
{
	NSArray	*colors = @[[NSColor redColor], [NSColor orangeColor], [NSColor yellowColor], [NSColor greenColor], [NSColor blueColor], [NSColor purpleColor]];
	NSGradient *gradient = [[NSGradient alloc] initWithColors:colors];
	return [gradient interpolatedColorAtLocation:index / (float)[self.tracks count]];
}

@end

#endif // !TARGET_OS_IPHONE

