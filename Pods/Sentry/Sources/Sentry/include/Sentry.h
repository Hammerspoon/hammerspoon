//
//  Sentry.h
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for Sentry.
FOUNDATION_EXPORT double SentryVersionNumber;

//! Project version string for Sentry.
FOUNDATION_EXPORT const unsigned char SentryVersionString[];

#import "SentrySerialization.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryCrash.h"
#import "SentrySDK.h"
#import "SentryHub.h"
#import "SentryClient.h"
#import "SentrySwizzle.h"

#import "SentryNSURLRequest.h"

#import "SentrySerializable.h"

#import "SentryEvent.h"
#import "SentryScope.h"
#import "SentryThread.h"
#import "SentryMechanism.h"
#import "SentryException.h"
#import "SentryStacktrace.h"
#import "SentryFrame.h"
#import "SentryUser.h"
#import "SentryDebugMeta.h"
#import "SentryBreadcrumb.h"
#import "SentryTransportFactory.h"
#import "SentryTransport.h"
#import "SentryHttpTransport.h"
#import "SentryInstallation.h"
#import "SentryCurrentDate.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrashExceptionApplication.h"
#import "SentryCrashInstallation.h"
#import "SentryCrashInstallation+Private.h"
#import "SentryError.h"
#import "SentryQueueableRequestManager.h"
#import "SentryTransportFactory.h"
#import "SentryRateLimitParser.h"
#import "SentryRateLimits.h"
#import "SentryDefaultRateLimits.h"
#import "SentryRateLimitCategory.h"
#import "SentryRateLimitCategoryMapper.h"
#import "SentryHttpDateParser.h"
