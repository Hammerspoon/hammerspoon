#import "CommandPostViewController.h"

@interface CommandPostViewController () <FCPXTimelineObserver>

@property (weak) IBOutlet NSButton *doSomething;

@property (weak) IBOutlet NSTextField *movePlayheadTextBox;
@property (weak) IBOutlet NSTextField *movePlayheadFramesTextBox;

@property (weak) IBOutlet NSScrollView *debugTextBox;
@end

@implementation CommandPostViewController

//
// Converts CMTime object into a human-readible string:
//
- (NSString*)CMTimeString:(CMTime) time {
    NSString *timeDescription = (NSString *)CFBridgingRelease(CMTimeCopyDescription(NULL, time));
    return timeDescription;
}

//
// Converts FCPXSequenceTimecodeFormat object into a human-readible string:
//
- (NSString*)fcpxSequenceTimecodeFormatString:(FCPXSequenceTimecodeFormat) timecodeFormat {
    NSString *fcpxSequenceTimecodeFormatString;
    if (timecodeFormat == kFCPXSequenceTimecodeFormat_DropFrame) {
        fcpxSequenceTimecodeFormatString = @"DropFrame";
    } else if (timecodeFormat == kFCPXSequenceTimecodeFormat_NonDropFrame) {
        fcpxSequenceTimecodeFormatString = @"NonDropFrame";
    } else if (timecodeFormat == kFCPXSequenceTimecodeFormat_Unspecified) {
        fcpxSequenceTimecodeFormatString = @"Unspecified";
    } else {
        fcpxSequenceTimecodeFormatString = @"Unknown";
    }
    return fcpxSequenceTimecodeFormatString;
}

//
// Converts FCPXObjectType object into a human-readible string:
//
- (NSString*)fcpxObjectTypeString:(FCPXObjectType) objectType {
    NSString *fcpxObjectTypeString;
    if (objectType == kFCPXObjectType_Event) {
        fcpxObjectTypeString = @"Event";
    } else if (objectType == kFCPXObjectType_Library) {
        fcpxObjectTypeString = @"Library";
    } else if (objectType == kFCPXObjectType_Project) {
        fcpxObjectTypeString = @"Project";
    } else if (objectType == kFCPXObjectType_Sequence) {
        fcpxObjectTypeString = @"Sequence";
    }
    return fcpxObjectTypeString;
}

//
// Adds a line to the Debug Textbox:
//
- (void)addDebugMessage:(NSString*) message {
    [self.debugTextBox.documentView insertText:[NSString stringWithFormat:@"%@\n", message]];
}

//
// Increment Button Pressed:
//
- (IBAction)incrementButton:(id)sender {
    
    // Get the current playhead time:
    CMTime time = [self.host.timeline playheadTime];
        
    // Get the timeline:
    FCPXTimeline *timeline = self.host.timeline;
    
    // Get the active sequence:
    FCPXSequence *activeSequence = timeline.activeSequence;
    
    // Get frame duration for active sequence:
    CMTime frameDuration = activeSequence.frameDuration;
    
    int howManyFramesToMove = self.movePlayheadFramesTextBox.intValue;

    CMTime howManyFrames = CMTimeMultiply(frameDuration, howManyFramesToMove);
    
    CMTime newTime = CMTimeAdd(time, howManyFrames);
    
    [self.host.timeline movePlayheadTo:newTime];
    
    // Write a debug message:
    [self addDebugMessage:@"incrementButton Pressed"];
}

//
// Move Playhead Button Pressed:
//
- (IBAction)movePlayheadButtonPressed:(id)sender {
    
    int movePlayheadTextBoxValue = self.movePlayheadTextBox.intValue;
    
    [self addDebugMessage:[NSString stringWithFormat:@"movePlayheadTextBoxValue: %d", movePlayheadTextBoxValue]];
    
    CMTime newTime = CMTimeMakeWithSeconds(movePlayheadTextBoxValue, NSEC_PER_SEC);
    
    [self addDebugMessage:[NSString stringWithFormat:@"newTime: %@", [self CMTimeString:newTime]]];
    
    [self.host.timeline movePlayheadTo:newTime];
    
    // Write a debug message:
    [self addDebugMessage:@"movePlayheadButtonPressed"];
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    //
    // Connect to the Final Cut Pro host:
    //
    id<FCPXHost> host = (id<FCPXHost>)ProExtensionHostSingleton();
    self.host = host;
    
    //
    // Add a new timeline observer:
    //
    [host.timeline addTimelineObserver:self];
    
    // Write a debug message:
    [self addDebugMessage:@"awakeFromNib"];
    
    // Write some debug messages about the host:
    [self addDebugMessage:[NSString stringWithFormat:@"host name: %@", self.host.name]];
    [self addDebugMessage:[NSString stringWithFormat:@"host versionString: %@", self.host.versionString]];
    [self addDebugMessage:[NSString stringWithFormat:@"host bundleIdentifier: %@", self.host.bundleIdentifier]];
}

- (NSString*) nibName
{
    // Return the NIB name:
    return @"CommandPostViewController";
}

//
// A callback method that gets invoked when there is a change in the current timeline sequence.
//
- (void) activeSequenceChanged
{
    // Get the timeline:
    FCPXTimeline *timeline = self.host.timeline;
    
    // Get the active sequence:
    FCPXSequence *activeSequence = timeline.activeSequence;
    
    // Get sequence parameters:
    NSString *name                              = activeSequence.name;
    
    CMTime startTime                            = activeSequence.startTime;
    NSString *startTimeString                   = [self CMTimeString:startTime];
    
    CMTime duration                             = activeSequence.duration;
    NSString *durationString                    = [self CMTimeString:duration];
    
    CMTime frameDuration                        = activeSequence.frameDuration;
    NSString *frameDurationString               = [self CMTimeString:frameDuration];
        
    FCPXObject *container                       = activeSequence.container;
    NSString *containerString                   = container.debugDescription;
    
    FCPXSequenceTimecodeFormat timecodeFormat   = activeSequence.timecodeFormat;
    NSString *fcpxSequenceTimecodeFormatString  = [self fcpxSequenceTimecodeFormatString:timecodeFormat];

    FCPXObjectType objectType                   = activeSequence.objectType;
    NSString *fcpxObjectTypeString              = [self fcpxObjectTypeString:objectType];
    
    // FCPXLibrary      - url name
    // FCPXEvent        - UID name
    // FCPXProject      - sequence UID name
    // FCPXSequence     - duration, frameDuration, startTime, timecodeFormat, name
    
    // Convert the parameters into something human readable:
    NSString *debugString = [NSString stringWithFormat:@"%@ - %@ - %@ - %@ - %@ - %@ - %@", name, durationString, containerString, frameDurationString, startTimeString, fcpxSequenceTimecodeFormatString, fcpxObjectTypeString];
    
    // Write a debug message:
    NSString *debugMessage = [NSString stringWithFormat:@"activeSequenceChanged: %@", debugString];
    [self addDebugMessage:debugMessage];
}

//
// A callback method that gets invoked when the playhead position changes in the Final Cut Pro timeline.
//
// Final Cut Pro invokes this method when:
//  * A user clicks the Final Cut Pro timeline view to move the playhead to a new position.
//  * A user drags the timeline playhead to a new position.
//  * Playback of the timeline sequence stops.
//  * A user clicks one of the markers displayed in the Tags tab on the Index panel.
//
// NOTE: Final Cut Pro does not invoke this method while a user is skimming through the
//       timeline or when the timeline sequence is playing.
//
- (void)playheadTimeChanged {
    // Get the current playhead time:
    CMTime time = [self.host.timeline playheadTime];
    
    // Convert it to a string for debugging:
    NSString *timeDescription = [self CMTimeString:time];
        
    // Write a debug message:
    NSString *debugMessage = [NSString stringWithFormat:@"playheadTimeChanged: %@", timeDescription];
    [self addDebugMessage:debugMessage];
}

//
// A callback method that gets invoked when the time range of an active sequence changes in the Final Cut Pro timeline.
//
// By observing for the changes in the time range of an active sequence, an extension can verify whether the data it
// has for the sequence is in sync with what is presented in Final Cut Pro.
//
- (void)sequenceTimeRangeChanged {
    
    // Get the timeline:
    FCPXTimeline *timeline = self.host.timeline;
    
    // Get the sequence time range:
    CMTimeRange sequenceTimeRange = timeline.sequenceTimeRange;
    
    CMTime start = sequenceTimeRange.start;
    CMTime duration = sequenceTimeRange.duration;
    
    NSString *startDescription = [self CMTimeString:start];
    NSString *durationDescription = [self CMTimeString:duration];
   
    // Write a debug message:
    NSString *debugMessage = [NSString stringWithFormat:@"sequenceTimeRangeChanged: start: %@ duration: %@", startDescription, durationDescription];
    [self addDebugMessage:debugMessage];
}

- (void)viewWillDisappear
{
    // Write a debug message:
    [self addDebugMessage:@"viewWillDisappear"];
    
    // Remove the timeline observer:
    [self.host.timeline removeTimelineObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Write a debug message:
    [self addDebugMessage:@"viewDidLoad"];
}

//
// Attempt to commit pending edits, returning an error in the case of failure.
//
// During autosaving, commit editing may fail, due to a pending edit. Rather than interrupt the user with an
// unexpected alert, this method provides the caller with the option to either present the error or fail
// silently, leaving the pending edit in place and the user's editing uninterrupted. In your implementation of
// this method, you should attempt to commit editing, but if there is a failure return NO and in error an
// error object to be presented or ignored as appropriate.
//
// Return YES if the commit is successful, otherwise NO.
//
- (BOOL)commitEditingAndReturnError:(NSError *__autoreleasing  _Nullable * _Nullable)error
{
    // Write a debug message:
    [self addDebugMessage:@"commitEditingAndReturnError"];
    return YES;
}

//
// Encodes the receiver using a given archiver.
//
// You don’t call this method directly. It’s called by a NSCoder subclass if it needs to serialize that
// object. If you want to encode an object graph use the class methods archivedDataWithRootObject: or
// archiveRootObject:toFile: of NSKeyedArchiver. This in turn will call the encodeWithCoder: method of your
// objects. Also note that every object in your array has to implement the NSCoding protocol.
//
- (void)encodeWithCoder:(nonnull NSCoder *)coder {
}

@end
