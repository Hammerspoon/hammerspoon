//
//  SUInstallerLauncher+Private.h
//  SUInstallerLauncher+Private
//
//  Created by Mayur Pawashe on 8/21/21.
//  Copyright © 2021 Sparkle Project. All rights reserved.
//

#ifndef SUInstallerLauncher_Private_h
#define SUInstallerLauncher_Private_h

#import <Sparkle/SUExport.h>

// Chances are clients will need this too
#import <Sparkle/SPUInstallationType.h>

@class NSString;

/**
 Private API for determining if the system needs authorization access to update a bundle path
 
 This API is not supported when used directly from a Sandboxed applications and will always return @c YES in that case.
 
 @param bundlePath The bundle path to test if authorization is needed when performing an update that replaces this bundle.
 @return @c YES if Sparkle thinks authorization is needed to update the @c bundlePath, otherwise @c NO.
 */
SU_EXPORT BOOL SPUSystemNeedsAuthorizationAccessForBundlePath(NSString *bundlePath);

#endif /* SUInstallerLauncher_Private_h */
