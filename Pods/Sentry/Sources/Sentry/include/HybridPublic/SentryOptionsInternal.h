#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOptionsInternal : NSObject

@property (nonatomic, readonly, class) NSArray<Class> *defaultIntegrationClasses;

+ (nullable SentryOptions *)initWithDict:(NSDictionary<NSString *, id> *)options
                        didFailWithError:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
