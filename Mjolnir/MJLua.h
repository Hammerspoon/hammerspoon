#import "lauxlib.h"
#import "lualib.h"

void MJLuaSetup(void);
void MJLuaSetupLogHandler(void(^blk)(NSString* str));
NSString* MJLuaRunString(NSString* command);
NSString* MJFindInitFile(void);
