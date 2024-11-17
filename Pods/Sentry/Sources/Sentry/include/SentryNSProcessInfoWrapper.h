#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryNSProcessInfoWrapper : NSObject

@property (nonatomic, readonly) NSString *processDirectoryPath;
@property (nullable, nonatomic, readonly) NSString *processPath;
@property (readonly) NSUInteger processorCount;

#if defined(TEST) || defined(TESTCI) || defined(DEBUG)
- (void)setProcessPath:(NSString *)path;
#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
