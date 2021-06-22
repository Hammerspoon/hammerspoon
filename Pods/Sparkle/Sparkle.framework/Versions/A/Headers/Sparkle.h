//
//  Sparkle.h
//  Sparkle
//
//  Created by Andy Matuschak on 3/16/06. (Modified by CDHW on 23/12/07)
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SPARKLE_H
#define SPARKLE_H

// This list should include the shared headers. It doesn't matter if some of them aren't shared (unless
// there are name-space collisions) so we can list all of them to start with:

#pragma clang diagnostic push
// Do not use <> style includes since 2.x has two frameworks that need to work: Sparkle and SparkleCore
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"

#import "SUAppcast.h"
#import "SUAppcastItem.h"
#import "SUStandardVersionComparator.h"
#import "SUUpdater.h"
#import "SUUpdaterDelegate.h"
#import "SUVersionComparisonProtocol.h"
#import "SUVersionDisplayProtocol.h"
#import "SUErrors.h"

#import "SPUDownloader.h"
#import "SPUDownloaderDelegate.h"
#import "SPUDownloadData.h"
#import "SPUDownloaderProtocol.h"
#import "SPUDownloaderSession.h"
#import "SPUURLRequest.h"
#import "SUCodeSigningVerifier.h"

#pragma clang diagnostic pop

#endif
