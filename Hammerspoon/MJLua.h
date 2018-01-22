#import <LuaSkin/LuaSkin.h>

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
NSArray *MJLuaCompletionsForWord(NSString *completionWord);

void callDockIconCallback(void);
void callAccessibilityStateCallback(void);
void textDroppedToDockIcon(NSString *pboardString);
void fileDroppedToDockIcon(NSString *filePath);
