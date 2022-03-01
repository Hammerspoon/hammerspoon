//
//  SPUStandardUserDriverDelegate.h
//  Sparkle
//
//  Created by Mayur Pawashe on 3/3/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#if __has_feature(modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif
#import <Sparkle/SUExport.h>

@protocol SUVersionDisplay;

/**
 A protocol for Sparkle's standard user driver's delegate
 
 This includes methods related to UI interactions
 */
SU_EXPORT @protocol SPUStandardUserDriverDelegate <NSObject>

@optional

/**
 Called before showing a modal alert window,
 to give the opportunity to hide attached windows that may get in the way.
 */
- (void)standardUserDriverWillShowModalAlert;

/**
 Called after showing a modal alert window,
 to give the opportunity to hide attached windows that may get in the way.
 */
- (void)standardUserDriverDidShowModalAlert;

/**
 Returns an object that formats version numbers for display to the user.
 If you don't implement this method or return @c nil, the standard version formatter will be used.
 */
- (_Nullable id <SUVersionDisplay>)standardUserDriverRequestsVersionDisplayer;

/**
 Handles showing the full release notes to the user.
 
 When a user checks for new updates and no new update is found, Sparkle will offer to show the application's version history to the user
 by providing a "Version History" button in the no new update available alert.
 
 If this delegate method is not implemented, Sparkle will instead offer to open the
 `fullReleaseNotesLink` (or `releaseNotesLink` if the former is unavailable) from the appcast's latest `item` in the user's web browser.
 
 If this delegate method is implemented, Sparkle will instead ask the delegate to show the full release notes to the user.
 A delegate may want to implement this method if they want to show in-app or offline release notes.
 
 @param item The appcast item corresponding to the latest version available.
 */
- (void)standardUserDriverShowVersionHistoryForAppcastItem:(SUAppcastItem *_Nonnull)item;

@end
