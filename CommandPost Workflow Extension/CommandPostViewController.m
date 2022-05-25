#import "CommandPostViewController.h"

/*
 
 COMMANDPOST WORKFLOW EXTENSION - SOCKETS API:
 =============================================
 
 Commands that can be SENT to the Workflow Extension:
                      ----
 
 PING           - Send a ping
 INCR f         - Increment by Frame                (where f is number of frames)
 DECR f         - Decrement by Frame                (where f is number of frames)
 GOTO s         - Goto Timeline Position            (where s is number of seconds)
 
 
 Commands that can be RECEIVED from the Workflow Extension:
                      --------
 
 DONE           - Connection successful
 DEAD           - Server is shutting down
 PONG           - Receive a pong
 PLHD s         - The playhead time has changed     (where s is playhead position in seconds)
 
 SEQC sequenceName || startTime || duration || frameDuration || container || timecodeFormat || objectType
                - The active sequence has changed
                                                    (sequenceName is a string)
                                                    (startTime in seconds)
                                                    (duration in seconds)
                                                    (frameDuration in seconds)
                                                    (container as a string)
                                                    (timecodeFormat as a string: DropFrame, NonDropFrame, Unspecified or Unknown)
                                                    (objectType as a string: Event, Library, Project, Sequence or Unknown)
 
 RNGC startTime || duration
                - The active sequence time range has changed
                                                    (startTime in seconds)
                                                    (duration in seconds)
 
 
 WORKFLOW EXTENSION API NOTES:
 -----------------------------
 
  * FCPXLibrary      - url name
  * FCPXEvent        - UID name
  * FCPXProject      - sequence UID name
  * FCPXSequence     - duration, frameDuration, startTime, timecodeFormat, name

 
 USEFUL LINKS:
 -------------
 
  * CMTime for Human Beings: https://dcordero.me/posts/cmtime-for-human-beings.html

 */

//
// VIEW CONTROLLER:
//

@interface CommandPostViewController () <FCPXTimelineObserver>

@property (weak) IBOutlet NSScrollView *debugTextBox;
@property (weak) IBOutlet NSTextField *statusTextField;
@property (weak) IBOutlet NSTextField *statusHeadingTextField;

@end

@implementation CommandPostViewController

#pragma mark SOCKETS SERVER

//
// Start the Socket Server:
//
- (void) startSocketServer
{
    // Update status in Workflow Extension UI:
    [self updateStatusEmoji:@"🟠"];
    [self updateStatus:@"Starting Server..." includeTimestamp:NO];
    
    // Setup a new dispatch queue for socket connection:
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    // Setup new CocoaAsyncSocket object:
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    // Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
    
    // The socket port we want to use for communication:
    UInt16 thePort = 43426;
    
    // Start Socket Server:
    NSError *error = nil;
    if (![listenSocket acceptOnPort:thePort error:&error]) {
        // Update status in Workflow Extension UI:
        [self updateStatusEmoji:@"🔴"];
        NSString *status = [NSString stringWithFormat:@"Socket Server Failed (Port: %hu)", thePort];
        [self updateStatus:status includeTimestamp:NO];

    } else {
        // Update status in Workflow Extension UI:
        [self updateStatusEmoji:@"🟠"];
        NSString *status = [NSString stringWithFormat:@"Server Started (Port: %hu)", thePort];
        [self updateStatus:status includeTimestamp:NO];
    }
}

//
// Stop the Socket Server:
//
- (void) stopSocketServer
{
    // Tell all our clients we're about to die:
    [self sendSocketMessage:@"DEAD"];
    
    // Stop accepting connections:
    [listenSocket disconnect];
    
    // Stop any client connections:
    @synchronized(connectedSockets)
    {
        NSUInteger i;
        for (i = 0; i < [connectedSockets count]; i++)
        {
            // Call disconnect on the socket,
            // which will invoke the socketDidDisconnect: method,
            // which will remove the socket from the list.
            [[connectedSockets objectAtIndex:i] disconnect];
        }
    }
}

//
// Send a Socket Message to all the connected client sockets.
//
- (void)sendSocketMessage:(NSString*) message
{
    // Add in the correct ending:
    NSString *newMessage = [NSString stringWithFormat:@"%@\r\n", message];
    
    // Send the message to all connected sockets:
    NSData *data = [newMessage dataUsingEncoding:NSUTF8StringEncoding];
    for (id socket in connectedSockets) {
        [socket writeData:data withTimeout:-1 tag:0];
    }
}

//
// Triggered when a new client socket connection is accepted.
//
// NOTE: This method is executed on the socketQueue (not the main thread)
//
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // Add the new socket to connected sockets:
    @synchronized(connectedSockets)
    {
        [connectedSockets addObject:newSocket];
    }
    
    // Get port name from new socket:
    UInt16 port = [newSocket connectedPort];
    
    // Update status in Workflow Extension UI:
    [self updateStatusEmoji:@"🟢"];
    NSString *status = [NSString stringWithFormat:@"Connected (Port: %hu)", port];
    [self updateStatus:status includeTimestamp:NO];
    
    // Send the success command:
    [self sendSocketMessage:@"DONE"];
    
    // Trigger all the notifications:
    [self activeSequenceChanged];
    [self playheadTimeChanged];
    [self sequenceTimeRangeChanged];
    
    // Read any data on the socket:
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

//
// Called when a socket has completed writing the requested data. Not called if there is an error.
//
// NOTE: This method is executed on the socketQueue (not the main thread)
//
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    // Read any data on the socket:
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

//
// Called when a socket has completed reading the requested data into memory. Not called if there is an error.
//
// NOTE: This method is executed on the socketQueue (not the main thread)
//
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    // Strip off the end of the data:
    NSData *trimmedData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
    
    // Convert the data into a string:
    NSString *message = [[NSString alloc] initWithData:trimmedData encoding:NSUTF8StringEncoding];
    if (!message) {
        // Update status in Workflow Extension UI:
        [self updateStatus:@"⛔️ Incoming data was invalid" includeTimestamp:NO];
        return;
    }
    
    // Get the command from the message:
    NSString *command = [message substringToIndex:4];;
    if (!command) {
        [self updateStatus:@"⛔️ No command detected" includeTimestamp:NO];
        return;
    }
    
    // Get the value from the message:
    NSString *value = nil;
    if ([message length] > 4) {
        NSRange valueRange = NSMakeRange(5, [message length] - 5);
        value = [message substringWithRange:valueRange];
    }

    // Make sure we're running any UI stuff on the main thread:
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            //
            // Process Commands:
            //
            NSArray *items = @[@"PING", @"INCR", @"DECR", @"GOTO"];
            unsigned long item = [items indexOfObject:command];
            switch (item) {
                case 0: {
                    //
                    // PING           - no additional attributes
                    //
                    [self sendSocketMessage:@"PONG"];
                    
                    // Update Status:
                    [self updateStatus:@"🏓 Ping Received" includeTimestamp:YES];
                    
                    break;
                }
                case 1: {
                    //
                    // INCR f         - where f is number of frames
                    //
                    NSNumber *frames = [self stringToNumber:value];
                    [self shiftTimelineInFrames:frames];
                    break;
                }
                case 2: {
                    //
                    // DECR f         - where f is number of frames
                    //
                    NSNumber *frames = [self stringToNumber:value];
                    NSNumber *reverseFrames = @(- frames.floatValue);
                    [self shiftTimelineInFrames:reverseFrames];
                    break;
                }
                case 3: {
                    //
                    // GOTO s         - where s is number of seconds
                    //
                    NSNumber *seconds = [self stringToNumber:value];
                    [self gotoTimelineValueInSeconds:seconds];
                    break;
                }
                default: {
                    //
                    // UNKNOWN COMMAND:
                    //
                    NSString *status = [NSString stringWithFormat:@"⛔️ Unknown Command: %@", command];
                    [self updateStatus:status includeTimestamp:NO];
                    break;
                }
            }
        }
    });
            
    // Read any data on connected sockets:
    for (id socket in connectedSockets) {
        [socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    }
}

//
// Called when a socket disconnects with or without error.
//
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock != listenSocket)
    {
        // Update status:
        [self updateStatusEmoji:@"🟠"];
        [self updateStatus:@"Disconnected" includeTimestamp:NO];
        
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
}

#pragma mark CONTROL FINAL CUT PRO

//
// Shift Timeline In Frames:
//
- (void) shiftTimelineInFrames:(NSNumber*) frames
{
    // Get the timeline:
    FCPXTimeline *timeline = self.host.timeline;
    
    // Get the active sequence:
    FCPXSequence *activeSequence = timeline.activeSequence;
    
    // Get frame duration for active sequence:
    CMTime frameDuration = activeSequence.frameDuration;
    
    // Multiply the Frame Duration by how many frames to move:
    CMTime howManyFrames = CMTimeMultiply(frameDuration, [frames floatValue]);
    
    // Get the current playhead time:
    CMTime time = [self.host.timeline playheadTime];
    
    // Add the current playhead time with how many frames:
    CMTime newTime = CMTimeAdd(time, howManyFrames);
    
    // Tell Final Cut Pro to move the playhead:
    [self.host.timeline movePlayheadTo:newTime];
    
    // Update Status:
    NSString *status;
    if ([frames intValue] > 0) {
        status = [NSString stringWithFormat:@"▶️ Move Playhead %@", frames];
    } else {
        status = [NSString stringWithFormat:@"◀️ Move Playhead %@", frames];
    }
    [self updateStatus:status includeTimestamp:YES];
}

//
// Go to Timeline Value in Seconds:
//
- (void) gotoTimelineValueInSeconds:(NSNumber*) seconds
{
    CMTime newTime = CMTimeMakeWithSeconds([seconds floatValue], NSEC_PER_SEC);
    [self.host.timeline movePlayheadTo:newTime];
    
    // Update Status:
    NSString *status = [NSString stringWithFormat:@"⏯ Goto %@", seconds];
    [self updateStatus:status includeTimestamp:YES];
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
    CMTime duration                             = activeSequence.duration;
    CMTime frameDuration                        = activeSequence.frameDuration;
        
    FCPXObject *container                       = activeSequence.container;
    NSString *containerString                   = container.debugDescription;
    
    FCPXSequenceTimecodeFormat timecodeFormat   = activeSequence.timecodeFormat;
    NSString *fcpxSequenceTimecodeFormatString  = [self fcpxSequenceTimecodeFormatString:timecodeFormat];

    FCPXObjectType objectType                   = activeSequence.objectType;
    NSString *fcpxObjectTypeString              = [self fcpxObjectTypeString:objectType];
        
    // Convert the parameters into something human readable:
    NSString *combined = [NSString stringWithFormat:@"%@ || %f || %f || %f || %@ || %@ || %@",
                             name,
                             CMTimeGetSeconds(startTime),
                             CMTimeGetSeconds(duration),
                             CMTimeGetSeconds(frameDuration),
                             containerString,
                             fcpxSequenceTimecodeFormatString,
                             fcpxObjectTypeString];
    
    // Write message to Socket:
    NSString *socketMessage = [NSString stringWithFormat:@"SEQC %@", combined];
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
    
    // Write message to Socket:
    NSString *socketMessage = [NSString stringWithFormat:@"PLHD %f", CMTimeGetSeconds(time)];
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
        
    // Write message to Socket:
    NSString *socketMessage = [NSString stringWithFormat:@"RNGC %f || %f", CMTimeGetSeconds(start), CMTimeGetSeconds(duration)];
    [self sendSocketMessage:socketMessage];
}

# pragma mark FINAL CUT PRO HELPER FUNCTIONS

//
// Converts a NSString into a NSNumber:
//
- (NSNumber*)stringToNumber:(NSString*) value {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *frames = [formatter numberFromString:value];
    return frames;
}

//
// Converts CMTime object into a human-readable string:
//
- (NSString*)CMTimeString:(CMTime) time {
    NSString *timeDescription = (NSString *)CFBridgingRelease(CMTimeCopyDescription(NULL, time));
    return timeDescription;
}

//
// Converts FCPXSequenceTimecodeFormat object into a human-readable string:
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
// Converts FCPXObjectType object into a human-readable string:
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
    } else {
        fcpxObjectTypeString = @"Unknown";
    }
    return fcpxObjectTypeString;
}

# pragma mark VIEW CONTROLLER MANAGEMENT

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    // Connect to Final Cut Pro:
    [self connectToFinalCutPro];
    
    // Start the Socket Server:
    [self startSocketServer];
}

- (NSString*) nibName
{
    // Return the NIB name:
    return @"CommandPostViewController";
}

- (void)viewWillDisappear
{
    // Probably not necessary, but for completeness, lets remove the timeline observer:
    [self.host.timeline removeTimelineObserver:self];
    
    // Again, probably not necessary, but lets stop the socket server:
    [self stopSocketServer];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

#pragma mark USER INTERFACE

//
// Update the Status Text in the Workflow Extension UI:
//
- (void)updateStatus:(NSString*) message includeTimestamp:(BOOL)includeTimestamp {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if (self && message) {
                NSString *newMessage = message;
                if (includeTimestamp) {
                    CFAbsoluteTime timeInSeconds = CFAbsoluteTimeGetCurrent();
                    newMessage = [NSString stringWithFormat:@"%@ (%f)", message, timeInSeconds];
                }
                self.statusTextField.stringValue = newMessage;
            }
        }
    });
}

//
// Update the Status Text in the Workflow Extension UI:
//
- (void)updateStatusEmoji:(NSString*) emoji {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if (self && emoji) {
                self.statusHeadingTextField.stringValue = [NSString stringWithFormat:@"Status: %@", emoji];
            }
        }
    });
}

//
// Open website when you click "Learn More":
//
- (IBAction)learnMoreButton:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSURL *url = [NSURL URLWithString:@"https://help.commandpost.io/workflow-extension/"];
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    });

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
