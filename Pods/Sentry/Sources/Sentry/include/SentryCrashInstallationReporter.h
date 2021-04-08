#import <Foundation/Foundation.h>

#import "SentryCrash.h"
#import "SentryCrashInstallation.h"

@interface SentryCrashInstallationReporter : SentryCrashInstallation

- (void)sendAllReports;

@end
