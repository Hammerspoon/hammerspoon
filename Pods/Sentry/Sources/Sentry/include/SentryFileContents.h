NS_ASSUME_NONNULL_BEGIN

@interface SentryFileContents : NSObject

- (instancetype)initWithPath:(NSString *) path andContents:(NSData *) contents;

@property(nonatomic, readonly, copy) NSString *path;
@property(nonatomic, readonly, weak) NSData *contents;

@end

NS_ASSUME_NONNULL_END
