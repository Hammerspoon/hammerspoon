#import "PHHotKey.h"
#import <Carbon/Carbon.h>

@implementation PHHotKey

static OSStatus SDHotkeyCallback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    
    // get shared script (maybe use inUserData?)
    // call "rawapi.hotkey_callback" with eventID.id
    
    return noErr;
}
- (void) listen:(NSDictionary*)hotKeyInfo name:(NSString*)name {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // one-time necessary setup
        
        EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
        InstallEventHandler(GetEventDispatcherTarget(), SDHotkeyCallback, 1, &hotKeyPressedSpec, (__bridge void*)self, NULL);
    });
    
    static int highestUID;
    int uid = ++highestUID;
    
    UInt32 mods = 0;
    if ([hotKeyInfo[@"command"] boolValue]) mods |= cmdKey;
    if ([hotKeyInfo[@"control"] boolValue]) mods |= controlKey;
    if ([hotKeyInfo[@"option"] boolValue]) mods |= optionKey;
    if ([hotKeyInfo[@"shift"] boolValue]) mods |= shiftKey;
    
    UInt32 key = [hotKeyInfo[@"key"] unsignedIntValue];
    
    EventHotKeyID hotKeyID = { .signature = 'PHNX', .id = uid };
    EventHotKeyRef carbonHotKey = NULL;
    RegisterEventHotKey(key, mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &carbonHotKey);
    
//    return uid, carbonHotKey;
}

@end
