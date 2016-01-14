#import <LuaSkin/LuaSkin.h>

@interface MJLuaLogger : NSObject <LuaSkinDelegate> {
    lua_State *_L;
}

@property (atomic, readonly) lua_State *L;

- (instancetype)initWithLua:(lua_State *)L  ;
@end

void MJLuaAlloc(void);
void MJLuaInit(void);
void MJLuaDeinit(void);
void MJLuaDealloc(void);

void MJLuaCreate(void);
void MJLuaDestroy(void);
void MJLuaReplace(void);

void MJLuaSetupLogHandler(void(^blk)(NSString* str));
NSString* MJLuaRunString(NSString* command);
NSString* MJFindInitFile(void);
