#import "lua/lauxlib.h"
#import "lua/lualib.h"

void MJLuaSetup(void);
void MJLuaSetupLogHandler(void(^blk)(NSString* str));
void MJLuaReloadConfig(void);
NSString* MJLuaRunString(NSString* command);
