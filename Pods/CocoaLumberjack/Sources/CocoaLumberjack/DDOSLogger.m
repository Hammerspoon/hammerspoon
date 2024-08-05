// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2024, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#import <TargetConditionals.h>
#import <os/log.h>

#import <CocoaLumberjack/DDOSLogger.h>

@implementation DDOSLogLevelMapperDefault

- (instancetype)init {
    self = [super init];
    return self;
}

- (os_log_type_t)osLogTypeForLogFlag:(DDLogFlag)logFlag {
    switch (logFlag) {
        case DDLogFlagError:
        case DDLogFlagWarning:
            return OS_LOG_TYPE_ERROR;
        case DDLogFlagInfo:
            return OS_LOG_TYPE_INFO;
        case DDLogFlagDebug:
        case DDLogFlagVerbose:
            return OS_LOG_TYPE_DEBUG;
        default:
            return OS_LOG_TYPE_DEFAULT;
    }
}

@end

#if TARGET_OS_SIMULATOR
@implementation DDOSLogLevelMapperSimulatorConsoleAppWorkaround

- (os_log_type_t)osLogTypeForLogFlag:(DDLogFlag)logFlag {
    __auto_type defaultMapping = [super osLogTypeForLogFlag:logFlag];
    return (defaultMapping == OS_LOG_TYPE_DEBUG) ? OS_LOG_TYPE_DEFAULT : defaultMapping;
}

@end
#endif

@interface DDOSLogger ()

@property (nonatomic, copy, readonly, nullable) NSString *subsystem;
@property (nonatomic, copy, readonly, nullable) NSString *category;
@property (nonatomic, strong, readonly, nonnull) os_log_t logger;

@end

@implementation DDOSLogger

@synthesize subsystem = _subsystem;
@synthesize category = _category;
@synthesize logLevelMapper = _logLevelMapper;
@synthesize logger = _logger;

#pragma mark - Shared Instance

API_AVAILABLE(macos(10.12), ios(10.0), watchos(3.0), tvos(10.0))
static DDOSLogger *sharedInstance;

+ (instancetype)sharedInstance {
    static dispatch_once_t DDOSLoggerOnceToken;

    dispatch_once(&DDOSLoggerOnceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });

    return sharedInstance;
}

#pragma mark - Initialization
- (instancetype)initWithSubsystem:(NSString *)subsystem category:(NSString *)category {
    NSAssert((subsystem == nil) == (category == nil), 
             @"Either both subsystem and category or neither should be nil.");
    if (self = [super init]) {
        _subsystem = [subsystem copy];
        _category = [category copy];
        _logLevelMapper = [[DDOSLogLevelMapperDefault alloc] init];
    }
    return self;
}

- (instancetype)init {
    return [self initWithSubsystem:nil category:nil];
}

- (instancetype)initWithSubsystem:(NSString *)subsystem
                         category:(NSString *)category
                   logLevelMapper:(id<DDOSLogLevelMapper>)logLevelMapper {
    if (self = [self initWithSubsystem:subsystem category:category]) {
        NSParameterAssert(logLevelMapper);
        _logLevelMapper = logLevelMapper;
    }
    return self;
}

- (instancetype)initWithLogLevelMapper:(id<DDOSLogLevelMapper>)logLevelMapper {
    return [self initWithSubsystem:nil category:nil logLevelMapper:logLevelMapper];
}

#pragma mark - Mapper
- (id<DDOSLogLevelMapper>)logLevelMapper {
    if (_logLevelMapper == nil) {
        _logLevelMapper = [[DDOSLogLevelMapperDefault alloc] init];
    }
    return _logLevelMapper;
}

#pragma mark - os_log
- (os_log_t)logger {
    if (_logger == nil)  {
        if (self.subsystem == nil || self.category == nil) {
            _logger = OS_LOG_DEFAULT;
        } else {
            _logger = os_log_create(self.subsystem.UTF8String, self.category.UTF8String);
        }
    }
    return _logger;
}

#pragma mark - DDLogger
- (DDLoggerName)loggerName {
    return DDLoggerNameOS;
}

- (void)logMessage:(DDLogMessage *)logMessage {
#if !TARGET_OS_WATCH // See DDASLLogCapture.m -> Was never supported on watchOS.
    // Skip captured log messages.
    if ([logMessage->_fileName isEqualToString:@"DDASLLogCapture"]) {
        return;
    }
#endif

    if (@available(iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0, *)) {
        __auto_type message = _logFormatter ? [_logFormatter formatLogMessage:logMessage] : logMessage->_message;
        if (message != nil) {
            __auto_type logType = [self.logLevelMapper osLogTypeForLogFlag:logMessage->_flag];
            os_log_with_type(self.logger, logType, "%{public}s", message.UTF8String);
        }
    }
}

@end
