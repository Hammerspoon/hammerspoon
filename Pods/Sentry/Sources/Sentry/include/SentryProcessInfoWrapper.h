#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryProcessInfoWrapper : NSObject

@property (nonatomic, readonly) NSString *processDirectoryPath;
@property (nullable, nonatomic, readonly) NSString *processPath;

@end

NS_ASSUME_NONNULL_END
