#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Random

- (double)nextNumber;

@end

@interface Random : NSObject <Random>

- (double)nextNumber;

@end

NS_ASSUME_NONNULL_END
