#import "lua/lauxlib.h"
#import "lua/lualib.h"

void MJLoadModule(NSString* fullname);
void MJUnloadModule(NSString* fullname);
void MJSetupLua(void);
void MJSetupLogHandler(void(^blk)(NSString* str));
void MJReloadConfig(void);
NSString* MJLuaRunString(NSString* command);
