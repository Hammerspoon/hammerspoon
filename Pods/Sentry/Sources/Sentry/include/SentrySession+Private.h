#import "SentrySession.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *nameForSentrySessionStatus(SentrySessionStatus status);

@interface
SentrySession ()

@property (nonatomic) NSUInteger errors;

- (void)setFlagInit;

@end

NS_ASSUME_NONNULL_END
