//
//  SUVersionDisplayProtocol.h
//  EyeTV
//
//  Created by Uli Kusterer on 08.12.09.
//  Copyright 2009 Elgato Systems GmbH. All rights reserved.
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

/**
    Applies special display formatting to version numbers.
*/
SU_EXPORT @protocol SUVersionDisplay

/**
    Formats two version strings.

    Both versions are provided so that important distinguishing information
    can be displayed while also leaving out unnecessary/confusing parts.
*/
- (void)formatVersion:(NSString *_Nonnull*_Nonnull)inOutVersionA andVersion:(NSString *_Nonnull*_Nonnull)inOutVersionB;

@end
