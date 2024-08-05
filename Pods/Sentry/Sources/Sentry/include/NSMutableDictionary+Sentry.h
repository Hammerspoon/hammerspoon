
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDictionary : NSObject

/**
 * Merges the otherDictionary into the given dictionary by overriding existing keys with the values
 * of the other dictionary.
 */
+ (void)mergeEntriesFromDictionary:(NSDictionary *)dictionary
                    intoDictionary:(NSMutableDictionary *)destination;

+ (void)setBoolValue:(nullable NSNumber *)value
              forKey:(NSString *)key
      intoDictionary:(NSMutableDictionary *)destination;

@end

NS_ASSUME_NONNULL_END
