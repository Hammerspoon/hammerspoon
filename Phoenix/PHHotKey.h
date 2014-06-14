#import <Foundation/Foundation.h>

@interface PHHotKey : NSObject

@property id carbonKey;
@property int code;

+ (PHHotKey*) listen:(NSString*)key mods:(UInt32)mods;
+ (void) disable:(id)carbonKey;

@end
