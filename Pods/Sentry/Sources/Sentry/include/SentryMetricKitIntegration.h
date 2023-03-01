#import "SentryBaseIntegration.h"
#import "SentryEvent.h"
#import "SentryIntegrationProtocol.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryMetricKitDiskWriteExceptionType = @"MXDiskWriteException";
static NSString *const SentryMetricKitDiskWriteExceptionMechanism = @"mx_disk_write_exception";

static NSString *const SentryMetricKitCpuExceptionType = @"MXCPUException";
static NSString *const SentryMetricKitCpuExceptionMechanism = @"mx_cpu_exception";

static NSString *const SentryMetricKitHangDiagnosticType = @"MXHangDiagnostic";
static NSString *const SentryMetricKitHangDiagnosticMechanism = @"mx_hang_diagnostic";

#if SENTRY_HAS_METRIC_KIT

API_AVAILABLE(ios(15.0), macos(12.0), macCatalyst(15.0))
API_UNAVAILABLE(tvos, watchos)
@interface SentryMetricKitIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryMXManagerDelegate>

@end

#endif

@interface
SentryEvent (MetricKit)

@property (nonatomic, readonly) BOOL isMetricKitEvent;

@end

NS_ASSUME_NONNULL_END
