#import <LuaSkin/LuaSkin.h>

void MJLuaSetup(void);
void MJLuaTeardown(void);
void MJLuaSetupLogHandler(void(^blk)(NSString* str));
NSString* MJLuaRunString(NSString* command);
NSString* MJFindInitFile(void);
