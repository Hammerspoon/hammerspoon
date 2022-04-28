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

@interface CommandPostViewController ()
@end


@implementation CommandPostViewController

- (void) awakeFromNib
{
    [super awakeFromNib];
}

- (NSString*) nibName
{
    return @"CommandPostViewController";
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


@end
