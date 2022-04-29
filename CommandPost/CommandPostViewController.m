//
//  CommandPostViewController.m
//  CommandPost
//
//  Created by Chris Hocking on 29/4/2022.
//  Copyright © 2022 LateNite Films. All rights reserved.
//


#import "CommandPostViewController.h"
#import <ProExtension/ProExtension.h>
#import <ProExtensionHost/ProExtensionHost.h>

@interface CommandPostViewController () <FCPXTimelineObserver>
@property (weak) IBOutlet NSButton *doSomething;
@end

@implementation CommandPostViewController
- (IBAction)doSomething:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Do something pressed!"];
    [alert setInformativeText:@"You pressed a button."];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];    
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    // Set up the timeline observer:
    id<FCPXHost> host = (id<FCPXHost>)ProExtensionHostSingleton();
    [host.timeline addTimelineObserver:self];
}

- (NSString*) nibName
{
    return @"CommandPostViewController";
}

- (void) activeSequenceChanged
{
    id<FCPXHost> host = (id<FCPXHost>)ProExtensionHostSingleton();
    FCPXSequence* sequence = host.timeline.activeSequence;
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"activeSequenceChanged"];
    [alert setInformativeText:sequence.name];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)playheadTimeChanged {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"playheadTimeChanged"];
    [alert setInformativeText:@""];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)sequenceTimeRangeChanged {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"sequenceTimeRangeChanged"];
    [alert setInformativeText:@""];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (NSString*) hostInfoString
{
    id<FCPXHost> host = (id<FCPXHost>)ProExtensionHostSingleton();
    
    return [NSString stringWithFormat:@"%@ %@", host.name, host.versionString];
}


- (BOOL)commitEditingAndReturnError:(NSError *__autoreleasing  _Nullable * _Nullable)error {
    
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    
}

@end
