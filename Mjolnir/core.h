#import "lua/lauxlib.h"
#import "lua/lualib.h"

extern lua_State* MJLuaState;
void MJLoadModule(NSString* fullname);
void MJUnloadModule(NSString* fullname);
void MJSetupLua(void);
void MJSetupLogHandler(void(^blk)(NSString* str));
void MJReloadConfig(void);
