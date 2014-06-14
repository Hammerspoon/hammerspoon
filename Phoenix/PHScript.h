#import <Foundation/Foundation.h>
#import "lua/lualib.h"

@interface PHScript : NSObject

+ (PHScript*) sharedScript;

- (void) reload;

@property lua_State* L;

@end
