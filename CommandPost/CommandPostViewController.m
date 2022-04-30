#import "CommandPostViewController.h"

/*
 
 COMMANDPOST WORKFLOW EXTENSION - SOCKETS API
 
 Commands that can be SENT to the Workflow Extension:

 PING           - Send a ping
 INCR f         - Increment by Frame        (where f is number of frames)
 DECR f         - Decrement by Frame        (where f is number of frames)
 GOTO s         - Goto Timeline Position    (where s is number of seconds)
 
 Commands that can be RECEIVED from the Workflow Extension:
 
 DONE           - Connection successful
 PONG           - Recieve a pong
 SEQC           - The active sequence has changed               (TBC)
 RNGC           - The active sequence time range has changed    (TBC)
 PLHD           - The playhead time has changed                 (TBC)
 
 
 USEFUL LINKS:
 
  * CMTime for Human Beings: https://dcordero.me/posts/cmtime-for-human-beings.html

 */

//
// VIEW CONTROLLER:
//

@interface CommandPostViewController () <FCPXTimelineObserver>

@property (weak) IBOutlet NSButton *doSomething;

@property (weak) IBOutlet NSTextField *movePlayheadTextBox;
@property (weak) IBOutlet NSTextField *movePlayheadFramesTextBox;

@property (weak) IBOutlet NSScrollView *debugTextBox;

@end

@implementation CommandPostViewController

#pragma mark SOCKETS SERVER

- (void) setupSocketServer
{
    [self addDebugMessage:@"Setting up Socket Server..."];
    
    //
    // Ideally we run on a new dispatch queue, but leave
    // the main queue code here for testing/problem-solving:
    //
    
    //socketQueue = dispatch_get_main_queue();
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    // Setup new CocoaAsyncSocket object:
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    // Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
    
    // The socket port we want to use for communication:
    UInt16 thePort = 43426;
    
    // Add some debug messaging:
    [self addDebugMessage:[NSString stringWithFormat:@"Setting up Socket Server on port: %hu", thePort]];
    
    // Start Socket Server:
    NSError *error = nil;
    if (![listenSocket acceptOnPort:thePort error:&error]) {
        NSString *errorMessage = [NSString stringWithFormat:@"Unable to bind port: %@", [error localizedDescription]];
        [self addDebugMessage:errorMessage];
    } else {
        [self addDebugMessage:@"Socket server started"];
    }
}

- (void)sendSocketMessage:(NSString*) message
{
    // Add Debug Message:
    [self addDebugMessage:[NSString stringWithFormat:@"sendSocketMessage: %@", message]];
    
    // Add in the correct ending:
    NSString *newMessage = [NSString stringWithFormat:@"%@\r\n", message];
    
    // Send the message to all connected sockets:
    NSData *data = [newMessage dataUsingEncoding:NSUTF8StringEncoding];
    for (id socket in connectedSockets) {
        [socket writeData:data withTimeout:-1 tag:99];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    //
    // NOTE: This method is executed on the socketQueue (not the main thread)
    //
    
    // Add the new socket to connected sockets:
    @synchronized(connectedSockets)
    {
        [connectedSockets addObject:newSocket];
    }
    
    // Get host name and port name from new socket:
    NSString *host = [newSocket connectedHost];
    UInt16 port = [newSocket connectedPort];
    
    // Add Debug Message:
    [self addDebugMessage:[NSString stringWithFormat:@"Accepted client %@:%hu", host, port]];
    
    // Send the success command:
    [self sendSocketMessage:@"DONE"];
    
    // Read any data on the socket:
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //
    // NOTE: This method is executed on the socketQueue (not the main thread)
    //
        
    // Add Debug Message:
    [self addDebugMessage:[NSString stringWithFormat:@"didWriteDataWithTag: %ld", tag]];
    
    // Read the data:
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //
    // NOTE: This method is executed on the socketQueue (not the main thread)
    //
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!message) {
                [self addDebugMessage:@"didReadData - Error converting received data into UTF-8 String"];
                return;
            }
            
            NSString *command = [message substringToIndex:4];;
            if (!command) {
                [self addDebugMessage:@"didReadData - Invalid command"];
                return;
            }
            
            [self addDebugMessage:[NSString stringWithFormat:@"didReadData message: %@", message]];
            [self addDebugMessage:[NSString stringWithFormat:@"didReadData command: %@", message]];
            
            //
            // Process Commands:
            //
            if ([command isEqualToString:@"PING"]) {
                //
                // PING
                //
                NSString *pong = @"PONG\r\n";
                NSData *pongData = [pong dataUsingEncoding:NSUTF8StringEncoding];
                [sock writeData:pongData withTimeout:-1 tag:0];
            } else if ([command isEqualToString:@"INCR"]) {
                //
                // INCR f         - where f is number of frames
                // 012345
                
                NSRange valueRange = NSMakeRange(5, [message length]);
                NSString *value = [message substringWithRange:valueRange];
                
                [self addDebugMessage:[NSString stringWithFormat:@"INCR REQUESTED: %@", value]];
                
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                formatter.numberStyle = NSNumberFormatterDecimalStyle;
                NSNumber *frames = [formatter numberFromString:value];
                
                [self shiftTimelineInFrames:frames];
                
            } else if ([command isEqualToString:@"DECR"]) {
                //
                // DECR f         - where f is number of frames
                //
                
                NSRange valueRange = NSMakeRange(5, [message length]);
                NSString *value = [message substringWithRange:valueRange];
                
                [self addDebugMessage:[NSString stringWithFormat:@"DECR REQUESTED: %@", value]];
            } else if ([command isEqualToString:@"GOTO"]) {
                //
                // GOTO s         - where s is number of seconds
                //
                
                NSRange valueRange = NSMakeRange(5, [message length]);
                NSString *value = [message substringWithRange:valueRange];
                
                [self addDebugMessage:[NSString stringWithFormat:@"GOTO REQUESTED: %@", value]];
            } else {
                [self addDebugMessage:@"didReadData - Unknown command"];
            }
        }
    });
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock != listenSocket)
    {
        // Add Debug Message:
        [self addDebugMessage:@"socketDidDisconnect"];

        // Remove the disconnected socket from connected sockets:
        @synchronized(connectedSockets)
        {
            [connectedSockets removeObject:sock];
        }
    }
}

#pragma mark CONNECT TO FINAL CUT PRO

- (void) connectToFinalCutPro
{
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

#pragma mark CONTROL FINAL CUT PRO

//
// Shift Timeline In Frames:
//
- (void) shiftTimelineInFrames:(NSNumber*) frames
{
    // Get the current playhead time:
    CMTime time = [self.host.timeline playheadTime];
        
    // Get the timeline:
    FCPXTimeline *timeline = self.host.timeline;
    
    // Get the active sequence:
    FCPXSequence *activeSequence = timeline.activeSequence;
    
    // Get frame duration for active sequence:
    CMTime frameDuration = activeSequence.frameDuration;
    
    // Multiply the Frame Duration by how many frames to move:
    CMTime howManyFrames = CMTimeMultiply(frameDuration, [frames intValue]);
    
    // Add the current playhead time with how many frames:
    CMTime newTime = CMTimeAdd(time, howManyFrames);
    
    // Tell Final Cut Pro to move the playhead:
    [self.host.timeline movePlayheadTo:newTime];
}

//
// Go to Timeline Value in Seconds:
//
- (void) gotoTimelineValueInSeconds:(NSNumber*) seconds
{
    CMTime newTime = CMTimeMakeWithSeconds([seconds intValue], NSEC_PER_SEC);
    [self.host.timeline movePlayheadTo:newTime];
}

#pragma mark FINAL CUT PRO OBSERVERS

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
    
    // Write message to Socket:
    NSString *socketMessage = [NSString stringWithFormat:@"SEQC %@", debugString];
    [self sendSocketMessage:socketMessage];
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
    
    // Write message to Socket:
    NSString *socketMessage = [NSString stringWithFormat:@"PLHD %@", timeDescription];
    [self sendSocketMessage:socketMessage];
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
    
    // Write message to Socket:
    NSString *socketMessage = [NSString stringWithFormat:@"RNGC %@ %@", startDescription, durationDescription];
    [self sendSocketMessage:socketMessage];
}

# pragma mark FINAL CUT PRO HELPER FUNCTIONS

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

# pragma mark VIEW CONTROLLER MANAGEMENT

- (void) awakeFromNib
{
    [super awakeFromNib];
    [self connectToFinalCutPro];
    [self setupSocketServer];
}

- (NSString*) nibName
{
    // Return the NIB name:
    return @"CommandPostViewController";
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

#pragma mark USER INTERFACE

//
// Adds a line to the Debug Textbox:
//
- (void)addDebugMessage:(NSString*) message {
    if (self && message) {
        //
        // Make sure we're running on the main thread:
        //
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [self.debugTextBox.documentView insertText:[NSString stringWithFormat:@"%@\n", message]];
            }
        });
    }
}

//
// Increment Button Pressed:
//
- (IBAction)incrementButton:(id)sender {
    
    // Goto Frame in the Textbox:
    NSNumber *frames = [NSNumber numberWithInt:self.movePlayheadFramesTextBox.intValue];
    [self shiftTimelineInFrames:frames];
    
    // Write a debug message:
    [self addDebugMessage:@"incrementButton Pressed"];
}

//
// Move Playhead Button Pressed:
//
- (IBAction)movePlayheadButtonPressed:(id)sender {
    
    // Goto Playhead Position from Seconds Value in Textbox:
    NSNumber *seconds =[NSNumber numberWithInt:self.movePlayheadTextBox.intValue];
    [self gotoTimelineValueInSeconds:seconds];
        
    // Write a debug message:
    [self addDebugMessage:@"movePlayheadButtonPressed"];
}

#pragma mark MISC

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
