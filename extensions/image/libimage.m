//#import <Appkit/NSImage.h>
@import LuaSkin ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wauto-import"
#import "ASCIImage/PARImage+ASCIIInput.h"
#pragma clang diagnostic pop

@import AVFoundation;

#define USERDATA_TAG "hs.image"
LSRefTable refTable = LUA_NOREF;

// NSWorkspace iconForFile: logs a warning every time you try to query when the path is nil.  Since
// this happens a lot when trying to query based on a file bundle it means anything using spotlight
// to gather file info and then uses this to get an icon can spam the system logs.  let's get it once
// and be done with it. (and while there is a NSImageNameMultipleDocuments, I can't seem to find one
// for a single document image...
static NSImage *missingIconForFile ;

static NSMutableSet *backgroundCallbacks ;

#pragma mark - Module Constants

/// hs.image.systemImageNames[]
/// Constant
/// Table containing the names of internal system images for use with hs.drawing.image
///
/// Notes:
///  * Image names pulled from NSImage.h
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.image.systemImageNames`.
static int pushNSImageNameTable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
        [skin pushNSObject:NSImageNameQuickLookTemplate] ;                       lua_setfield(L, -2, "QuickLookTemplate") ;
        [skin pushNSObject:NSImageNameBluetoothTemplate] ;                       lua_setfield(L, -2, "BluetoothTemplate") ;
        [skin pushNSObject:NSImageNameIChatTheaterTemplate] ;                    lua_setfield(L, -2, "IChatTheaterTemplate") ;
        [skin pushNSObject:NSImageNameSlideshowTemplate] ;                       lua_setfield(L, -2, "SlideshowTemplate") ;
        [skin pushNSObject:NSImageNameActionTemplate] ;                          lua_setfield(L, -2, "ActionTemplate") ;
        [skin pushNSObject:NSImageNameSmartBadgeTemplate] ;                      lua_setfield(L, -2, "SmartBadgeTemplate") ;
        [skin pushNSObject:NSImageNameIconViewTemplate] ;                        lua_setfield(L, -2, "IconViewTemplate") ;
        [skin pushNSObject:NSImageNameListViewTemplate] ;                        lua_setfield(L, -2, "ListViewTemplate") ;
        [skin pushNSObject:NSImageNameColumnViewTemplate] ;                      lua_setfield(L, -2, "ColumnViewTemplate") ;
        [skin pushNSObject:NSImageNameFlowViewTemplate] ;                        lua_setfield(L, -2, "FlowViewTemplate") ;
        [skin pushNSObject:NSImageNamePathTemplate] ;                            lua_setfield(L, -2, "PathTemplate") ;
        [skin pushNSObject:NSImageNameInvalidDataFreestandingTemplate] ;         lua_setfield(L, -2, "InvalidDataFreestandingTemplate") ;
        [skin pushNSObject:NSImageNameLockLockedTemplate] ;                      lua_setfield(L, -2, "LockLockedTemplate") ;
        [skin pushNSObject:NSImageNameLockUnlockedTemplate] ;                    lua_setfield(L, -2, "LockUnlockedTemplate") ;
        [skin pushNSObject:NSImageNameGoForwardTemplate] ;                       lua_setfield(L, -2, "GoForwardTemplate") ;
        [skin pushNSObject:NSImageNameGoBackTemplate] ;                          lua_setfield(L, -2, "GoBackTemplate") ;
        [skin pushNSObject:NSImageNameGoRightTemplate] ;                         lua_setfield(L, -2, "GoRightTemplate") ;
        [skin pushNSObject:NSImageNameGoLeftTemplate] ;                          lua_setfield(L, -2, "GoLeftTemplate") ;
        [skin pushNSObject:NSImageNameRightFacingTriangleTemplate] ;             lua_setfield(L, -2, "RightFacingTriangleTemplate") ;
        [skin pushNSObject:NSImageNameLeftFacingTriangleTemplate] ;              lua_setfield(L, -2, "LeftFacingTriangleTemplate") ;
        [skin pushNSObject:NSImageNameAddTemplate] ;                             lua_setfield(L, -2, "AddTemplate") ;
        [skin pushNSObject:NSImageNameRemoveTemplate] ;                          lua_setfield(L, -2, "RemoveTemplate") ;
        [skin pushNSObject:NSImageNameRevealFreestandingTemplate] ;              lua_setfield(L, -2, "RevealFreestandingTemplate") ;
        [skin pushNSObject:NSImageNameFollowLinkFreestandingTemplate] ;          lua_setfield(L, -2, "FollowLinkFreestandingTemplate") ;
        [skin pushNSObject:NSImageNameEnterFullScreenTemplate] ;                 lua_setfield(L, -2, "EnterFullScreenTemplate") ;
        [skin pushNSObject:NSImageNameExitFullScreenTemplate] ;                  lua_setfield(L, -2, "ExitFullScreenTemplate") ;
        [skin pushNSObject:NSImageNameStopProgressTemplate] ;                    lua_setfield(L, -2, "StopProgressTemplate") ;
        [skin pushNSObject:NSImageNameStopProgressFreestandingTemplate] ;        lua_setfield(L, -2, "StopProgressFreestandingTemplate") ;
        [skin pushNSObject:NSImageNameRefreshTemplate] ;                         lua_setfield(L, -2, "RefreshTemplate") ;
        [skin pushNSObject:NSImageNameRefreshFreestandingTemplate] ;             lua_setfield(L, -2, "RefreshFreestandingTemplate") ;
        [skin pushNSObject:NSImageNameBonjour] ;                                 lua_setfield(L, -2, "Bonjour") ;
        [skin pushNSObject:NSImageNameComputer] ;                                lua_setfield(L, -2, "Computer") ;
        [skin pushNSObject:NSImageNameFolderBurnable] ;                          lua_setfield(L, -2, "FolderBurnable") ;
        [skin pushNSObject:NSImageNameFolderSmart] ;                             lua_setfield(L, -2, "FolderSmart") ;
        [skin pushNSObject:NSImageNameFolder] ;                                  lua_setfield(L, -2, "Folder") ;
        [skin pushNSObject:NSImageNameNetwork] ;                                 lua_setfield(L, -2, "Network") ;
        [skin pushNSObject:NSImageNameMobileMe] ;                                lua_setfield(L, -2, "MobileMe") ;
        [skin pushNSObject:NSImageNameMultipleDocuments] ;                       lua_setfield(L, -2, "MultipleDocuments") ;
        [skin pushNSObject:NSImageNameUserAccounts] ;                            lua_setfield(L, -2, "UserAccounts") ;
        [skin pushNSObject:NSImageNamePreferencesGeneral] ;                      lua_setfield(L, -2, "PreferencesGeneral") ;
        [skin pushNSObject:NSImageNameAdvanced] ;                                lua_setfield(L, -2, "Advanced") ;
        [skin pushNSObject:NSImageNameInfo] ;                                    lua_setfield(L, -2, "Info") ;
        [skin pushNSObject:NSImageNameFontPanel] ;                               lua_setfield(L, -2, "FontPanel") ;
        [skin pushNSObject:NSImageNameColorPanel] ;                              lua_setfield(L, -2, "ColorPanel") ;
        [skin pushNSObject:NSImageNameUser] ;                                    lua_setfield(L, -2, "User") ;
        [skin pushNSObject:NSImageNameUserGroup] ;                               lua_setfield(L, -2, "UserGroup") ;
        [skin pushNSObject:NSImageNameEveryone] ;                                lua_setfield(L, -2, "Everyone") ;
        [skin pushNSObject:NSImageNameUserGuest] ;                               lua_setfield(L, -2, "UserGuest") ;
        [skin pushNSObject:NSImageNameMenuOnStateTemplate] ;                     lua_setfield(L, -2, "MenuOnStateTemplate") ;
        [skin pushNSObject:NSImageNameMenuMixedStateTemplate] ;                  lua_setfield(L, -2, "MenuMixedStateTemplate") ;
        [skin pushNSObject:NSImageNameApplicationIcon] ;                         lua_setfield(L, -2, "ApplicationIcon") ;
        [skin pushNSObject:NSImageNameTrashEmpty] ;                              lua_setfield(L, -2, "TrashEmpty") ;
        [skin pushNSObject:NSImageNameTrashFull] ;                               lua_setfield(L, -2, "TrashFull") ;
        [skin pushNSObject:NSImageNameHomeTemplate] ;                            lua_setfield(L, -2, "HomeTemplate") ;
        [skin pushNSObject:NSImageNameBookmarksTemplate] ;                       lua_setfield(L, -2, "BookmarksTemplate") ;
        [skin pushNSObject:NSImageNameCaution] ;                                 lua_setfield(L, -2, "Caution") ;
        [skin pushNSObject:NSImageNameStatusAvailable] ;                         lua_setfield(L, -2, "StatusAvailable") ;
        [skin pushNSObject:NSImageNameStatusPartiallyAvailable] ;                lua_setfield(L, -2, "StatusPartiallyAvailable") ;
        [skin pushNSObject:NSImageNameStatusUnavailable] ;                       lua_setfield(L, -2, "StatusUnavailable") ;
        [skin pushNSObject:NSImageNameStatusNone] ;                              lua_setfield(L, -2, "StatusNone") ;
        [skin pushNSObject:NSImageNameShareTemplate] ;                           lua_setfield(L, -2, "ShareTemplate") ;

        [skin pushNSObject:NSImageNameTouchBarAddDetailTemplate] ;               lua_setfield(L, -2, "TouchBarAddDetailTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAddTemplate] ;                     lua_setfield(L, -2, "TouchBarAddTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAlarmTemplate] ;                   lua_setfield(L, -2, "TouchBarAlarmTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioInputMuteTemplate] ;          lua_setfield(L, -2, "TouchBarAudioInputMuteTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioInputTemplate] ;              lua_setfield(L, -2, "TouchBarAudioInputTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioOutputMuteTemplate] ;         lua_setfield(L, -2, "TouchBarAudioOutputMuteTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioOutputVolumeHighTemplate] ;   lua_setfield(L, -2, "TouchBarAudioOutputVolumeHighTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioOutputVolumeLowTemplate] ;    lua_setfield(L, -2, "TouchBarAudioOutputVolumeLowTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioOutputVolumeMediumTemplate] ; lua_setfield(L, -2, "TouchBarAudioOutputVolumeMediumTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarAudioOutputVolumeOffTemplate] ;    lua_setfield(L, -2, "TouchBarAudioOutputVolumeOffTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarBookmarksTemplate] ;               lua_setfield(L, -2, "TouchBarBookmarksTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarColorPickerFill] ;                 lua_setfield(L, -2, "TouchBarColorPickerFill") ;
        [skin pushNSObject:NSImageNameTouchBarColorPickerFont] ;                 lua_setfield(L, -2, "TouchBarColorPickerFont") ;
        [skin pushNSObject:NSImageNameTouchBarColorPickerStroke] ;               lua_setfield(L, -2, "TouchBarColorPickerStroke") ;
        [skin pushNSObject:NSImageNameTouchBarCommunicationAudioTemplate] ;      lua_setfield(L, -2, "TouchBarCommunicationAudioTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarCommunicationVideoTemplate] ;      lua_setfield(L, -2, "TouchBarCommunicationVideoTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarComposeTemplate] ;                 lua_setfield(L, -2, "TouchBarComposeTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarDeleteTemplate] ;                  lua_setfield(L, -2, "TouchBarDeleteTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarDownloadTemplate] ;                lua_setfield(L, -2, "TouchBarDownloadTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarEnterFullScreenTemplate] ;         lua_setfield(L, -2, "TouchBarEnterFullScreenTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarExitFullScreenTemplate] ;          lua_setfield(L, -2, "TouchBarExitFullScreenTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarFastForwardTemplate] ;             lua_setfield(L, -2, "TouchBarFastForwardTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarFolderCopyToTemplate] ;            lua_setfield(L, -2, "TouchBarFolderCopyToTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarFolderMoveToTemplate] ;            lua_setfield(L, -2, "TouchBarFolderMoveToTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarFolderTemplate] ;                  lua_setfield(L, -2, "TouchBarFolderTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarGetInfoTemplate] ;                 lua_setfield(L, -2, "TouchBarGetInfoTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarGoBackTemplate] ;                  lua_setfield(L, -2, "TouchBarGoBackTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarGoDownTemplate] ;                  lua_setfield(L, -2, "TouchBarGoDownTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarGoForwardTemplate] ;               lua_setfield(L, -2, "TouchBarGoForwardTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarGoUpTemplate] ;                    lua_setfield(L, -2, "TouchBarGoUpTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarHistoryTemplate] ;                 lua_setfield(L, -2, "TouchBarHistoryTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarIconViewTemplate] ;                lua_setfield(L, -2, "TouchBarIconViewTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarListViewTemplate] ;                lua_setfield(L, -2, "TouchBarListViewTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarMailTemplate] ;                    lua_setfield(L, -2, "TouchBarMailTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarNewFolderTemplate] ;               lua_setfield(L, -2, "TouchBarNewFolderTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarNewMessageTemplate] ;              lua_setfield(L, -2, "TouchBarNewMessageTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarOpenInBrowserTemplate] ;           lua_setfield(L, -2, "TouchBarOpenInBrowserTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarPauseTemplate] ;                   lua_setfield(L, -2, "TouchBarPauseTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarPlayheadTemplate] ;                lua_setfield(L, -2, "TouchBarPlayheadTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarPlayPauseTemplate] ;               lua_setfield(L, -2, "TouchBarPlayPauseTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarPlayTemplate] ;                    lua_setfield(L, -2, "TouchBarPlayTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarQuickLookTemplate] ;               lua_setfield(L, -2, "TouchBarQuickLookTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarRecordStartTemplate] ;             lua_setfield(L, -2, "TouchBarRecordStartTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarRecordStopTemplate] ;              lua_setfield(L, -2, "TouchBarRecordStopTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarRefreshTemplate] ;                 lua_setfield(L, -2, "TouchBarRefreshTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarRewindTemplate] ;                  lua_setfield(L, -2, "TouchBarRewindTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarRotateLeftTemplate] ;              lua_setfield(L, -2, "TouchBarRotateLeftTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarRotateRightTemplate] ;             lua_setfield(L, -2, "TouchBarRotateRightTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSearchTemplate] ;                  lua_setfield(L, -2, "TouchBarSearchTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarShareTemplate] ;                   lua_setfield(L, -2, "TouchBarShareTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSidebarTemplate] ;                 lua_setfield(L, -2, "TouchBarSidebarTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipAhead15SecondsTemplate] ;      lua_setfield(L, -2, "TouchBarSkipAhead15SecondsTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipAhead30SecondsTemplate] ;      lua_setfield(L, -2, "TouchBarSkipAhead30SecondsTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipAheadTemplate] ;               lua_setfield(L, -2, "TouchBarSkipAheadTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipBack15SecondsTemplate] ;       lua_setfield(L, -2, "TouchBarSkipBack15SecondsTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipBack30SecondsTemplate] ;       lua_setfield(L, -2, "TouchBarSkipBack30SecondsTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipBackTemplate] ;                lua_setfield(L, -2, "TouchBarSkipBackTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipToEndTemplate] ;               lua_setfield(L, -2, "TouchBarSkipToEndTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSkipToStartTemplate] ;             lua_setfield(L, -2, "TouchBarSkipToStartTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarSlideshowTemplate] ;               lua_setfield(L, -2, "TouchBarSlideshowTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTagIconTemplate] ;                 lua_setfield(L, -2, "TouchBarTagIconTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextBoldTemplate] ;                lua_setfield(L, -2, "TouchBarTextBoldTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextBoxTemplate] ;                 lua_setfield(L, -2, "TouchBarTextBoxTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextCenterAlignTemplate] ;         lua_setfield(L, -2, "TouchBarTextCenterAlignTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextItalicTemplate] ;              lua_setfield(L, -2, "TouchBarTextItalicTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextJustifiedAlignTemplate] ;      lua_setfield(L, -2, "TouchBarTextJustifiedAlignTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextLeftAlignTemplate] ;           lua_setfield(L, -2, "TouchBarTextLeftAlignTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextListTemplate] ;                lua_setfield(L, -2, "TouchBarTextListTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextRightAlignTemplate] ;          lua_setfield(L, -2, "TouchBarTextRightAlignTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextStrikethroughTemplate] ;       lua_setfield(L, -2, "TouchBarTextStrikethroughTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarTextUnderlineTemplate] ;           lua_setfield(L, -2, "TouchBarTextUnderlineTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarUserAddTemplate] ;                 lua_setfield(L, -2, "TouchBarUserAddTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarUserGroupTemplate] ;               lua_setfield(L, -2, "TouchBarUserGroupTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarUserTemplate] ;                    lua_setfield(L, -2, "TouchBarUserTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarVolumeDownTemplate] ;              lua_setfield(L, -2, "TouchBarVolumeDownTemplate") ;
        [skin pushNSObject:NSImageNameTouchBarVolumeUpTemplate] ;                lua_setfield(L, -2, "TouchBarVolumeUpTemplate") ;

    return 1;
}

/// hs.image.additionalImageNames[]
/// Constant
/// Table of arrays containing the names of additional internal system images which may also be available for use with `hs.drawing.image` and [hs.image.imageFromName](#imageFromName).
///
/// Notes:
///  * The list of these images was pulled from a collection located in the repositories at https://github.com/hetima?tab=repositories.  As these image names are (for the most part) not formally listed in Apple's documentation or published APIs, their use cannot be guaranteed across all OS X versions.  If you identify any images which may be missing or could be added, please file an issue at https://github.com/Hammerspoon/hammerspoon.
static int additionalImages(lua_State *L) {
    lua_newtable(L) ;
    lua_newtable(L) ;
    lua_pushstring(L, "NSAddBookmarkTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSAudioOutputMuteTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSAudioOutputVolumeHighTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSAudioOutputVolumeLowTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSAudioOutputVolumeMedTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSAudioOutputVolumeOffTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSChildContainerEmptyTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSChildContainerTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDropDownIndicatorTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSGoLeftSmall") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSGoRightSmall") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuMixedStateTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuOnStateTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.normal") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.normalSelected") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.pressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.rollover") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.small.normal") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.small.normalSelected") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.small.pressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavEjectButton.small.rollover") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSPathLocationArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSPrivateArrowNextTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSPrivateArrowPreviousTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSPrivateChaptersTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScriptTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSecurity") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusAvailableFlat") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusAway") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusIdle") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusNoneFlat") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusOffline") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusPartiallyAvailableFlat") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusUnavailableFlat") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSStatusUnknown") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSynchronize") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTitlebarEnterFullScreenTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTitlebarExitFullScreenTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTokenPopDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "undocumentedImages") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSFastForwardTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSPauseTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSPlayTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRecordStartTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRecordStopTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRewindTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSkipAheadTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSkipBackTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "mediaControl") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSToolbarBookmarks") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarClipIndicator") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarCustomizeToolbarItemImage") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarFlexibleSpaceItemPaletteRep") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarMoreTemplate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarPrintItemImage") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarShowColorsItemImage") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarShowFontsItemImage") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSToolbarSpaceItemPaletteRep") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "toolbar") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSMediaBrowserIcon") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMediaBrowserMediaTypeAudio") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMediaBrowserMediaTypeAudioTemplate32") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMediaBrowserMediaTypeMovies") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMediaBrowserMediaTypeMoviesTemplate32") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMediaBrowserMediaTypePhotos") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMediaBrowserMediaTypePhotosTemplate32") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "mediaBrowser") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSCMYKButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorPickerCrayon") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorPickerList") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorPickerSliders") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorPickerUser") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorPickerWheel") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorProfileButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorProfileButtonSelected") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSColorSwatchResizeDimple") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSGreyButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHSBButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMagnifyingGlass") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRGBButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallMagnifyingGlass") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "colorPicker") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSFontPanelActionButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelActionButtonPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelBlurEffect") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelDropEffect") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelDropEffectPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelEffectsDivider") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelMinusIdle") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelMinusPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelOpacityEffect") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelPaperColour") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelPaperColourPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelPlusIdle") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelPlusPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelSliderThumb") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelSliderThumbPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelSliderTrack") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelSplitterKnob") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelSpreadEffect") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelStrikeEffect") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelStrikeEffectPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelTextColour") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelTextColourPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelUnderlineEffect") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSFontPanelUnderlineEffectPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "fontPanel") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSDatePickerCalendarArrowLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDatePickerCalendarArrowRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDatePickerCalendarHome") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDatePickerClockCenter") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDatePickerClockFace") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "datePicker") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSTextRulerCenterTab") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerDecimalTab") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerFirstLineIndent") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerIndent") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerLeftTab") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerRightTab") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "ruler") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSArrowCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSClosedHandCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSCopyDragCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSCrosshairCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSGenericDragCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHandCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSIBeamCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSLinkDragCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMoveCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSResizeLeftCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSResizeLeftRightCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSResizeRightCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthBottomLeftResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthBottomRightResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthHResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthHorizontalResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthTopLeftResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthTopRightResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthVResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthVerticalResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWaitCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "cursorLegacy") ;

    lua_newtable(L) ;
    lua_pushstring(L, "NSAppleMenuImage") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSBrowserCellBranch") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSBrowserCellBranchH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSClosedHandCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSCopyDragCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSCrosshairCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDocEditing") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSDocSaved") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSGenericDragCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSGrayResizeCorner") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHandCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHighlightedLinkButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHighlightedMenuArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHighlightedScrollDownButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHighlightedScrollLeftButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHighlightedScrollRightButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSHighlightedScrollUpButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSLeftMenuBarCap") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSLinkButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSLinkDragCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacPopUpArrows") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacPullDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacSmallPopUpArrows") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacSmallPullDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacSubmenuArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacTinyPopUpArrows") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMacTinyPullDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuBackTabKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuCheckmark") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuClearKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuCommandKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuControlKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuDeleteBackwardKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuDeleteForwardKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuDownArrowKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuDownScrollArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuEndKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuEnterKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuEscapeKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuHelpKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuHomeKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuISOControlKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuLeftArrowKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuMixedState") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuOptionKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuPageDownKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuPageUpKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuRadio") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuReturnKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuRightArrowKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuShiftKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuTabKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuUpArrowKeyGlyph") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuUpScrollArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMenuWindowDirtyState") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMiniTextAlignCenter") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMiniTextAlignJust") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMiniTextAlignLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMiniTextAlignRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMiniTextList") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSMoveCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonFillActive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonFillInactive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonFillPressedAqua") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonFillPressedGraphite") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonLeftActive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonLeftInactive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonLeftPressedAqua") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonLeftPressedGraphite") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonRightActive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonRightInactive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonRightPressedAqua") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarButtonRightPressedGraphite") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarLeftAngleActive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarLeftAngleInactive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarLeftAnglePressedAqua") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarLeftAnglePressedGraphite") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarRightAngleActive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarRightAngleInactive") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarRightAnglePressedAqua") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSNavigationBarRightAnglePressedGraphite") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonDisabledMixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonDisabledOff") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonDisabledOn") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonEnabledMixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonEnabledOff") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonEnabledOn") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonFocusRing") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonHighlightedMixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonHighlightedOff") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRadioButtonHighlightedOn") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSResizeLeftCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSResizeLeftRightCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSResizeRightCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSRightMenuBarCap") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollDownArrowDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollDownButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollLeftArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollLeftArrowDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollLeftButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollRightArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollRightArrowDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollRightButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollUpArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollUpArrowDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSScrollUpButton") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobAbove") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobAboveDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobAbovePressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobBelow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobBelowDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobBelowPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobHorizontal") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobHorizontalDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobHorizontalPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobLeftDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobLeftPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobRightDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobRightPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobVertical") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobVerticalDisabled") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSliderKnobVerticalPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveFill_Active_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveFill_Disabled_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveFill_Pressed_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveLeftCap_Active_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveLeftCap_Disabled_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveLeftCap_Pressed_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveRightCap_Active_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveRightCap_Disabled_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSmallSCurveRightCap_Pressed_Textured") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchDisabledMixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchDisabledOff") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchDisabledOn") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchEnabledMixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchEnabledOff") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchEnabledOn") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchFocusRing") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchHighlightedMixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchHighlightedOff") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSSwitchHighlightedOn") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTableViewDropBetweenCircleMarker") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerAlignCentered") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerAlignJustified") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerAlignLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerAlignRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerIndentFirst") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerIndentLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerIndentRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerLineHeightDecrease") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerLineHeightFixed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerLineHeightFlexible") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerLineHeightIncrease") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerMarginLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerMarginRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerTabCenter") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerTabDecimal") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerTabLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTextRulerTabRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSThemeWindowDocument") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleNormalDown") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleNormalRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTrianglePressedDown") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTrianglePressedRDown") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTrianglePressedRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleWhite-Collapsed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleWhite-Expanded") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleWhite-Pressed-Collapsed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleWhite-Pressed-Expanded") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTriangleWhite-Turning") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthClose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthCloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthCollapse") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthCollapseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthEditedClose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthEditedCloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthHResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthHorizontalResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthMiniDocument") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthMiniDocumentEdited") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthVResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthVerticalResizeCursor") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthZoom") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSTruthZoomH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityClose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityCloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityCollapse") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityCollapseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityEditedClose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityEditedCloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityZoom") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSUtilityZoomH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWin95BrowserBranch") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWin95ComboBoxDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWin95HighlightedBrowserBranch") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWin95PopUpArrows") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWin95PullDownArrow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinHighRadio") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinHighSwitch") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinRadio") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobAbove") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobAbovePressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobBelow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobBelowPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobHorizontal") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobHorizontalPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobLeftPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobRightPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobVertical") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSliderKnobVerticalPressed") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWinSwitch") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowClose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowCloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowCollapse") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowCollapseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowEditedClose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowEditedCloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowMiniDocument") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowMiniDocumentEdited") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowZoom") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NSWindowZoomH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "platinum") ;


    lua_newtable(L) ;
    lua_pushstring(L, "NXAppTile") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXBreak") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXBreakAll") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXFollow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey0") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey1") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey2") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey3") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey4") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey5") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXGrey6") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHDestLinkChain") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHSrcLinkChain") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHelpBacktrack") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHelpFind") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHelpIndex") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHelpMarker") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXHelpMarkerH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXMagnifier") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXUpdate") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXVDestLinkChain") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXVSrcLinkChain") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXauto") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXcircle16") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXcircle16H") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXclose") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXcloseH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXdefaultappicon") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXdefaulticon") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXdivider") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXdividerH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXediting") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXfirstindent") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXhSliderKnob") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXiconify") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXiconifyH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXleftindent") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXleftmargin") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXmanual") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXminiWindow") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXminiWorld") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXpopup") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXpopupH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXpulldown") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXpulldownH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXresize") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXresizeH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXresizeKnob") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXresizeKnobH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXrightindent") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXrightmargin") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollKnob") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuDown") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuDownD") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuDownH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuLeft") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuLeftD") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuLeftH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuRight") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuRightD") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuRightH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuUp") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuUpD") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXscrollMenuUpH") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXsquare16") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXsquare16H") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXtab") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXvSliderKnob") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushstring(L, "NXwait") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_setfield(L, -2, "NX") ;

    return 1 ;
}

#pragma mark - Module Functions

/// hs.image.getExifFromPath(path) -> table | nil
/// Function
/// Gets the EXIF metadata information from an image file.
///
/// Parameters:
///  * path - The path to the image file.
///
/// Returns:
///  * A table of EXIF metadata, or `nil` if no metadata can be found or the file path is invalid.
static int getExifFromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    
    NSString* imagePath = [skin toNSObjectAtIndex:1];
    imagePath = [imagePath stringByExpandingTildeInPath];
    imagePath = [[imagePath componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
    
    // SOURCE: https://stackoverflow.com/a/18301470
    NSURL *imageFileURL = [NSURL fileURLWithPath:imagePath];
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)imageFileURL, NULL);
    NSDictionary *treeDict;
    NSDictionary *exifTree;
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache,
                             nil];

    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, ( CFDictionaryRef)options);
    CFRelease(imageSource);
    if (imageProperties) {
        treeDict = [NSDictionary dictionaryWithDictionary:(NSDictionary*)CFBridgingRelease(imageProperties)];
        exifTree = [treeDict objectForKey:@"{Exif}"];
    }
    
    if (exifTree) {
        [skin pushNSObject:exifTree];
    } else {
        lua_pushnil(L);
    }
    
    return 1 ;
}

/// hs.image.imageFromPath(path) -> object
/// Constructor
/// Loads an image file
///
/// Parameters:
///  * path - A string containing the path to an image file on disk
///
/// Returns:
///  * An `hs.image` object, or nil if an error occured
static int imageFromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString* imagePath = [skin toNSObjectAtIndex:1];
    imagePath = [imagePath stringByExpandingTildeInPath];
    imagePath = [[imagePath componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
    NSImage *newImage = [[NSImage alloc] initByReferencingFile:imagePath];

    if (newImage && newImage.valid) {
        [skin pushNSObject:newImage];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.image.imageFromASCII(ascii[, context]) -> object
/// Constructor
/// Creates an image from an ASCII representation with the specified context.
///
/// Parameters:
///  * ascii - A string containing a representation of an image
///  * context - An optional table containing the context for each shape in the image.  A shape is considered a single drawing element (point, ellipse, line, or polygon) as defined at https://github.com/cparnot/ASCIImage and http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/.
///    * The context table is an optional (possibly sparse) array in which the index represents the order in which the shapes are defined.  The last (highest) numbered index in the sparse array specifies the default settings for any unspecified index and any settings which are not explicitly set in any other given index.
///    * Each index consists of a table which can contain one or more of the following keys:
///      * fillColor - the color with which the shape will be filled (defaults to black)  Color is defined in a table containing color component values between 0.0 and 1.0 for each of the keys:
///        * red (default 0.0)
///        * green (default 0.0)
///        * blue (default 0.0)
///        * alpha (default 1.0)
///      * strokeColor - the color with which the shape will be stroked (defaults to black)
///      * lineWidth - the line width (number) for the stroke of the shape (defaults to 1 if anti-aliasing is on or (√2)/2 if it is off -- approximately 0.7)
///      * shouldClose - a boolean indicating whether or not the shape should be closed (defaults to true)
///      * antialias - a boolean indicating whether or not the shape should be antialiased (defaults to true)
///
/// Returns:
///  * An `hs.image` object, or nil if an error occured
///
/// Notes:
///  * To use the ASCII diagram image support, see https://github.com/cparnot/ASCIImage and http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/
///  * The default for lineWidth, when antialiasing is off, is defined within the ASCIImage library. Geometrically it represents one half of the hypotenuse of the unit right-triangle and is a more accurate representation of a "real" point size when dealing with arbitrary angles and lines than 1.0 would be.
static int imageWithContextFromASCII(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];
    NSString *imageASCII = [skin toNSObjectAtIndex:1];

    if ([imageASCII hasPrefix:@"ASCII:"]) { imageASCII = [imageASCII substringFromIndex: 6]; }
    imageASCII = [imageASCII stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSArray *rep = [imageASCII componentsSeparatedByString:@"\n"];

    NSColor *defaultFillColor   = [NSColor blackColor] ;
    NSColor *defaultStrokeColor = [NSColor blackColor] ;
    BOOL     defaultAntiAlias   = YES ;
    BOOL     defaultShouldClose = YES ;
    CGFloat  defaultLineWidth   = (double)NAN ;

    NSMutableDictionary *contextTable = [[NSMutableDictionary alloc] init] ;
    lua_Integer          maxIndex     = 0 ;

    // build context from table

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            maxIndex = [skin maxNatIndex:2] ;
// NSLog(@"maxIndex = %d", maxIndex) ;
            if (maxIndex == 0) break ;

            lua_pushnil(L);  /* first key */
            while (lua_next(L, 2) != 0) { // 'key' (at index -2) and 'value' (at index -1)
                if (lua_istable(L, -1) && lua_isinteger(L, -2)) {
                    NSMutableDictionary *thisEntry = [[NSMutableDictionary alloc] init] ;

                    if (lua_getfield(L, -1, "fillColor") == LUA_TTABLE)
                        [thisEntry setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:@"fillColor"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "strokeColor") == LUA_TTABLE)
                        [thisEntry setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:@"strokeColor"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "lineWidth") == LUA_TNUMBER)
                        [thisEntry setObject:@(lua_tonumber(L, -1)) forKey:@"lineWidth"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "shouldClose") == LUA_TBOOLEAN)
                        [thisEntry setObject:@(lua_toboolean(L, -1)) forKey:@"shouldClose"];
                    lua_pop(L, 1);

                    if (lua_getfield(L, -1, "antialias") == LUA_TBOOLEAN)
                        [thisEntry setObject:@(lua_toboolean(L, -1)) forKey:@"antialias"];
                    lua_pop(L, 1);

                    if ([thisEntry count] > 0)
                        [contextTable setObject:thisEntry forKey:@(lua_tointeger(L, -2))];
                }
                lua_pop(L, 1);  // removes 'value'; keeps 'key' for next iteration
            }

            if ([contextTable count] == 0) {
                maxIndex = 0 ;
                break ;
            }

            if ([contextTable objectForKey:@(maxIndex)]) {
                NSDictionary *tableEndObject = [contextTable objectForKey:@(maxIndex)] ;
                if ([tableEndObject objectForKey:@"fillColor"])
                    defaultFillColor = [tableEndObject objectForKey:@"fillColor"] ;
                if ([tableEndObject objectForKey:@"strokeColor"])
                    defaultStrokeColor = [tableEndObject objectForKey:@"strokeColor"] ;
                if ([tableEndObject objectForKey:@"antialias"])
                    defaultAntiAlias = [[tableEndObject objectForKey:@"antialias"] boolValue] ;
                if ([tableEndObject objectForKey:@"shouldClose"])
                    defaultShouldClose = [[tableEndObject objectForKey:@"shouldClose"] boolValue] ;
                if ([tableEndObject objectForKey:@"lineWidth"])
                    defaultLineWidth = [[tableEndObject objectForKey:@"lineWidth"] doubleValue] ;
            }
            break;
        case LUA_TNIL:
        case LUA_TNONE:
            break;
        default:
            return luaL_error(L, "Unexpected type passed to hs.image.imageWithContextFromASCII as the context table: %s", lua_typename(L, lua_type(L, 2))) ;
    }

    if (isnan(defaultLineWidth)) { defaultLineWidth = defaultAntiAlias ? 1.0 : sqrt(2.0)/2.0; }

// NSLog(@"contextTable: %@", contextTable) ;

    NSImage *newImage = [NSImage imageWithASCIIRepresentation:rep
                                               contextHandler:^(NSMutableDictionary *context) {
              NSInteger index = [context[ASCIIContextShapeIndex] integerValue];
              context[ASCIIContextFillColor]       = defaultFillColor ;
              context[ASCIIContextStrokeColor]     = defaultStrokeColor ;
              context[ASCIIContextLineWidth]       = @(defaultLineWidth) ;
              context[ASCIIContextShouldClose]     = @(defaultShouldClose) ;
              context[ASCIIContextShouldAntialias] = @(defaultAntiAlias) ;
// NSLog(@"Checking Shape #: %ld", index) ;
              if ((index + 1) <= maxIndex) {
                  NSDictionary *currentObject = [contextTable objectForKey:@(index + 1)] ;
                  if (currentObject) {
                      if ([currentObject objectForKey:@"fillColor"])
                          context[ASCIIContextFillColor] = [currentObject objectForKey:@"fillColor"] ;
                      if ([currentObject objectForKey:@"strokeColor"])
                          context[ASCIIContextStrokeColor] = [currentObject objectForKey:@"strokeColor"] ;
                      if ([currentObject objectForKey:@"antialias"])
                          context[ASCIIContextShouldAntialias] = [currentObject objectForKey:@"antialias"] ;
                      if ([currentObject objectForKey:@"shouldClose"])
                          context[ASCIIContextShouldClose] = [currentObject objectForKey:@"shouldClose"] ;
                      if ([currentObject objectForKey:@"lineWidth"])
                          context[ASCIIContextLineWidth] = [currentObject objectForKey:@"lineWidth"] ;
                  }
              }
// NSLog(@"specificContext = %@", context) ;
          }] ;

    if (newImage) {
        [skin pushNSObject:newImage];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.image.imageFromName(string) -> object
/// Constructor
/// Returns the hs.image object for the specified name, if it exists.
///
/// Parameters:
///  * Name - the name of the image to return.
///
/// Returns:
///  * An hs.image object or nil, if no image was found with the specified name.
///
/// Notes:
///  * Some predefined labels corresponding to OS X System default images can be found in `hs.image.systemImageNames`.
///  * Names are not required to be unique: The search order is as follows, and the first match found is returned:
///     * an image whose name was explicitly set with the `setName` method since the last full restart of Hammerspoon
///     * Hammerspoon's main application bundle
///     * the Application Kit framework (this is where most of the images listed in `hs.image.systemImageNames` are located)
///  * Image names can be assigned by the image creator or by calling the `hs.image:setName` method on an hs.image object.
static int imageFromName(lua_State *L) {
    const char* imageName = luaL_checkstring(L, 1) ;

    NSString *imageNSName = [NSString stringWithUTF8String:imageName] ;
    NSImage *newImage = imageNSName ? [NSImage imageNamed:imageNSName] : nil ;
    if (newImage) {
        [[LuaSkin sharedWithState:L] pushNSObject:newImage] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.image.imageFromURL(url[, callbackFn]) -> object
/// Constructor
/// Creates an `hs.image` object from the contents of the specified URL.
///
/// Parameters:
///  * url - a web url specifying the location of the image to retrieve
///  * callbackFn - an optional callback function to be called when the image fetching is complete
///
/// Returns:
///  * An `hs.image` object or nil, if the url does not specify image contents or is unreachable, or if a callback function is supplied
///
/// Notes:
///  * If a callback function is supplied, this function will return nil immediately and the image will be fetched asynchronously
static int imageFromURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK] ;
    NSURL *theURL = [NSURL URLWithString:[skin toNSObjectAtIndex:1]] ;
    if (!theURL) {
        lua_pushnil(L);
        return 1;
    }

    if (lua_type(L, 2) != LUA_TFUNCTION) {
        [skin pushNSObject:[[NSImage alloc] initWithContentsOfURL:theURL]] ;
    } else {
        int fnRef = [skin luaRef:refTable atIndex:2];
        [backgroundCallbacks addObject:@(fnRef)] ;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            NSImage *image = [[NSImage alloc] initWithContentsOfURL:theURL];

            dispatch_async(dispatch_get_main_queue(), ^(void){
                if ([backgroundCallbacks containsObject:@(fnRef)]) {
                    LuaSkin *bgSkin = [LuaSkin sharedWithState:NULL];
                    _lua_stackguard_entry(bgSkin.L);

                    [bgSkin pushLuaRef:refTable ref:fnRef];
                    [bgSkin pushNSObject:image];
                    [bgSkin protectedCallAndTraceback:1 nresults:0];
                    [bgSkin luaUnref:refTable ref:fnRef];

                    _lua_stackguard_exit(bgSkin.L);
                    [backgroundCallbacks removeObject:@(fnRef)] ;
                }
            });
        });
        lua_pushnil(L);
    }

    return 1 ;
}

/// hs.image.imageFromAppBundle(bundleID) -> object
/// Constructor
/// Creates an `hs.image` object using the icon from an App
///
/// Parameters:
///  * bundleID - A string containing the bundle identifier of an application
///
/// Returns:
///  * An `hs.image` object or nil, if no app icon was found
static int imageFromApp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    NSString *imagePath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[skin toNSObjectAtIndex:1]];
    NSImage *iconImage = imagePath ? [[NSWorkspace sharedWorkspace] iconForFile:imagePath] : missingIconForFile ;

    if (iconImage) {
        [skin pushNSObject:iconImage];
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.image.iconForFile(file) -> object
/// Constructor
/// Creates an `hs.image` object for the file or files specified
///
/// Parameters:
///  * file - the path to a file or an array of files to generate an icon for.
///
/// Returns:
///  * An `hs.image` object or nil, if there was an error.  The image will be the icon for the specified file or an icon representing multiple files if an array of multiple files is specified.
static int imageForFiles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TSTRING, LS_TBREAK] ;
    NSArray *theFiles ;
    if (lua_type(L, 1) == LUA_TSTRING) {
        theFiles = [NSArray arrayWithObject:[skin toNSObjectAtIndex:1]] ;
    } else {
        theFiles = [skin toNSObjectAtIndex:1] ;
    }
    NSMutableArray *filesArray = [[NSMutableArray alloc] init] ;
    for (id item in theFiles) {
        if ([item isKindOfClass:[NSString class]]) {
            [filesArray addObject:[item stringByExpandingTildeInPath]] ;
        } else {
            return luaL_error(L, "invalid type, array of strings required") ;
        }
    }
    NSImage *theImage = [[NSWorkspace sharedWorkspace] iconForFiles:filesArray] ;
    if (theImage) {
        [skin pushNSObject:theImage];
    } else {
        lua_pushnil(L);
    }
    return 1 ;
}

/// hs.image.iconForFileType(fileType) -> object
/// Constructor
/// Creates an `hs.image` object of the icon for the specified file type.
///
/// Parameters:
///  * fileType - the file type, specified as a filename extension or a universal type identifier (UTI).
///
/// Returns:
///  * An `hs.image` object or nil, if there was an error
static int imageForFileType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSImage *theImage = [[NSWorkspace sharedWorkspace] iconForFileType:[skin toNSObjectAtIndex:1]] ;
    if (theImage) {
        [skin pushNSObject:theImage];
    } else {
        lua_pushnil(L);
    }
    return 1 ;
}

/// hs.image.imageFromMediaFile(file) -> object
/// Constructor
/// Creates an `hs.image` object from a video file or the album artwork of an audio file or directory
///
/// Parameters:
///  * file - A string containing the path to an audio or video file or an album directory
///
/// Returns:
///  * An `hs.image` object
///
/// Notes:
///  * If a thumbnail can be generated for a video file, it is returned as an `hs.image` object, otherwise the filetype icon
///  * For audio files, this function first determines the containing directory (if not already a directory)
///  * It checks if any of the following common filenames for album art are present:
///   * cover.jpg
///   * front.jpg
///   * art.jpg
///   * album.jpg
///   * folder.jpg
///  * If one of the common album art filenames is found, it is returned as an `hs.image` object
///  * This is faster than extracting image metadata and allows for obtaining artwork associated with file formats such as .flac/.ogg
///  * If no common album art filenames are found, it attempts to extract image metadata from the file. This works for .mp3/.m4a files
///  * If embedded image metadata is found, it is returned as an `hs.image` object, otherwise the filetype icon
static int imageFromMediaFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *theFilePath = [skin toNSObjectAtIndex:1] ;
    theFilePath = [theFilePath stringByExpandingTildeInPath];
    BOOL isDirectory;
    NSString *theDirectory;
    NSImage *theImage;

    // Bail if bad path
    if (![[NSFileManager defaultManager] fileExistsAtPath:theFilePath isDirectory:&isDirectory]) {
        imageForFiles(L);
        return 1;
    }

    // If file has a movie UTI, try to generate an image from it
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                            (__bridge CFStringRef)[theFilePath pathExtension],
                                                            (__bridge CFStringRef)@"public.movie");

    if (!CFStringHasPrefix(UTI, (__bridge CFStringRef)@"dyn")) { // UTI prefixed with "dyn" if not member of specified category
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:theFilePath]];
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        NSError *error;
        CGImageRef generatedImage = [imageGenerator copyCGImageAtTime:CMTimeMake(0, 10) actualTime:NULL error:&error];
        if (!error) {
            theImage = [[NSImage alloc] initWithCGImage:generatedImage size:NSZeroSize];
        } else [skin logError:[NSString stringWithFormat:@"Unable to generate image from video: %@", error]];
    }
    CFRelease(UTI);

    if (!theImage) {
        if (!isDirectory) { // Get the directory
            NSString *fileParent = [[[NSURL fileURLWithPath:theFilePath] URLByDeletingLastPathComponent] path];
            [[NSFileManager defaultManager] fileExistsAtPath:fileParent isDirectory:&isDirectory];
            if (isDirectory) theDirectory = fileParent;
        } else theDirectory = theFilePath;

        // Attempt to get image from very common album artwork filenames in the directory
        for (NSString *coverArtFile in @[@"cover", @"front", @"art", @"album", @"folder"]) {
            NSString *imagePath = [NSString stringWithFormat:@"%@/%@.jpg", theDirectory, coverArtFile];
            if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
                theImage = [[NSImage alloc] initByReferencingFile:imagePath];
                if (theImage && theImage.valid) break;
            }
        }
    }

    if (!theImage) { // Try to obtain album artwork from embedded metadata in .mp3/.m4a file itself
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:theFilePath]];
        NSArray<AVMetadataItem *> *metadataItems = [asset commonMetadata];
        for (AVMetadataItem *item in metadataItems) {
            if ([item.keySpace isEqualToString:AVMetadataKeySpaceID3] ||
                [item.keySpace isEqualToString:AVMetadataKeySpaceiTunes]) {
                NSData *itemData = [item dataValue] ;
                theImage = itemData ? [[NSImage alloc] initWithData:itemData] : nil ;
                if (theImage && theImage.valid) break;
            }
        }
    }

    if (theImage && theImage.valid) {
        [skin pushNSObject:theImage];
    } else {
        imageForFiles(L);
    }
    return 1;
}

#pragma mark - Module Methods

/// hs.image:name([name]) -> imageObject | string
/// Method
/// Get or set the name of the image represented by the hs.image object.
///
/// Parameters:
///  * `name` - an optional string specifying the new name for the hs.image object.
///
/// Returns:
///  * if no argument is provided, returns the current name.  If a new name is specified, returns the hs.image object or nil if the name cannot be changed.
///
/// Notes:
///  * see also [hs.image:setName](#setName) for a variant that returns a boolean instead.
static int getImageName(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSImage *testImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    if (lua_gettop(L) == 1) {
        lua_pushstring(L, [[testImage name] UTF8String]) ;
    } else {
        if ([testImage setName:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]]) {
            lua_pushvalue(L, 1) ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs.image:size([size, [absolute]] ) -> imageObject | size
/// Method
/// Get or set the size of the image represented byt he hs.image object.
///
/// Parameters:
///  * `size`     - an optional table with 'h' and 'w' keys specifying the size for the image.
///  * `absolute` - when specifying a new size, an optional boolean, default false, specifying whether or not the image should be resized to the height and width specified (true), or whether the copied image should be scaled proportionally to fit within the height and width specified (false).
///
/// Returns:
///  * If arguments are provided, return the hs.image object; otherwise returns the current size
///
/// Notes:
///  * See also [hs.image:setSize](#setSize) for creating a copy of the image at a new size.
static int getImageSize(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    NSImage *theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSSize:[theImage size]] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSSize  destSize  = [skin tableToSizeAtIndex:2] ;
        BOOL    absolute  = (lua_gettop(L) == 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
        if (absolute) {
            [theImage setSize:destSize] ;
        } else {
            NSSize srcSize = [theImage size] ;
            CGFloat multiplier = fmin(destSize.width / srcSize.width, destSize.height / srcSize.height) ;
            [theImage setSize:NSMakeSize(srcSize.width * multiplier, srcSize.height * multiplier)] ;
        }
        [skin pushNSObject:theImage];
    }
    return 1 ;
}

/// hs.image:colorAt(point) -> table
/// Method
/// Reads the color of the pixel at the specified location.
///
/// Parameters:
///  * `point` - a `hs.geometry.point`
///
/// Returns:
///  * A `hs.drawing.color` object
static int colorAt(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;

    // Source: https://stackoverflow.com/a/33485218/6925202
    @autoreleasepool {
    	NSImage *theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    	NSPoint point  = [skin tableToPointAtIndex:2] ;

		// Source: https://stackoverflow.com/a/48400410
		[theImage lockFocus];
		NSColor *pixelColor = NSReadPixel(point);
		[theImage unlockFocus];
        [skin pushNSObject:pixelColor];
	}

    return 1;
}

/// hs.image:croppedCopy(rectangle) -> object
/// Method
/// Returns a copy of the portion of the image specified by the rectangle specified.
///
/// Parameters:
///  * rectangle - a table with 'x', 'y', 'h', and 'w' keys specifying the portion of the image to return in the new image.
///
/// Returns:
///  * a copy of the portion of the image specified
static int croppedCopy(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    NSImage *theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSRect  frame  = [skin tableToRectAtIndex:2] ;

    // size changes may not actually affect representations until the image is composited, so...
    // http://stackoverflow.com/a/36451307
    NSRect targetRect = NSMakeRect(0.0, 0.0, theImage.size.width, theImage.size.height);
    NSImage *newImage = [[NSImage alloc] initWithSize:targetRect.size];
    [newImage lockFocus];
    [theImage drawInRect:targetRect fromRect:targetRect operation:NSCompositingOperationCopy fraction:1.0];
    [newImage unlockFocus];

// http://stackoverflow.com/questions/35643020/nsimage-drawinrect-and-nsview-cachedisplayinrect-memory-retained
    const void *keys[]   = { kCGImageSourceShouldCache } ;
    const void *values[] = { kCFBooleanFalse } ;
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)[newImage TIFFRepresentation], options);
    CGImageRef maskRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    // correct for retina displays
    NSSize actualSize = NSMakeSize(CGImageGetWidth(maskRef), CGImageGetHeight(maskRef)) ;
    CGFloat xFactor = actualSize.width / newImage.size.width ;
    CGFloat yFactor = actualSize.height / newImage.size.height ;
    NSRect correctedFrame = NSMakeRect(
        frame.origin.x * xFactor,
        frame.origin.y * yFactor,
        frame.size.width * xFactor,
        frame.size.height * yFactor
    ) ;
    CGImageRef imageRef = CGImageCreateWithImageInRect(maskRef, correctedFrame);
    NSImage *cropped = [[NSImage alloc] initWithCGImage:imageRef size:frame.size];
    CGImageRelease(maskRef);
    CGImageRelease(imageRef);
    CFRelease(source);
    CFRelease(options) ;

    [skin pushNSObject:cropped] ;
    return 1 ;
}

/// hs.image:encodeAsURLString([scale], [type]) -> string
/// Method
/// Returns a bitmap representation of the image as a base64 encoded URL string
///
/// Parameters:
///  * scale - an optional boolean, default false, which indicates that the image size (which macOS represents as points) should be scaled to pixels.  For images that have Retina scale representations, this may result in an encoded image which is scaled down from the original source.
///  * type  - optional case-insensitive string paramater specifying the bitmap image type for the encoded string (default PNG)
///    * PNG  - save in Portable Network Graphics (PNG) format
///    * TIFF - save in Tagged Image File Format (TIFF) format
///    * BMP  - save in Windows bitmap image (BMP) format
///    * GIF  - save in Graphics Image Format (GIF) format
///    * JPEG - save in Joint Photographic Experts Group (JPEG) format
///
/// Returns:
///  * the bitmap image representation as a Base64 encoded string
///
/// Notes:
///  * You can convert the string back into an image object with [hs.image.imageFromURL](#URL), e.g. `hs.image.imageFromURL(string)`
static int encodeAsString(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    NSImage*  theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;

    BOOL     scaleToPixels = lua_isboolean(L, 2) ? (BOOL)lua_toboolean(L, 2) : NO ;
    NSString *typeLabel    = @"png" ;
    if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TSTRING, LS_TBREAK] ;
        if (lua_type(L, 2) == LUA_TSTRING) {
            typeLabel = [skin toNSObjectAtIndex:2] ;
        }
    } else if (lua_gettop(L) > 2) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TSTRING, LS_TBREAK] ;
        typeLabel = [skin toNSObjectAtIndex:3] ;
    } // else it's 1 and we no longer need to check

    NSBitmapImageFileType fileType = NSPNGFileType ;

    if      ([typeLabel compare:@"PNG"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSPNGFileType  ; }
    else if ([typeLabel compare:@"TIFF" options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSTIFFFileType ; }
    else if ([typeLabel compare:@"BMP"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSBMPFileType  ; }
    else if ([typeLabel compare:@"GIF"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSGIFFileType  ; }
    else if ([typeLabel compare:@"JPEG" options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSJPEGFileType ; }
    else if ([typeLabel compare:@"JPG"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSJPEGFileType ; }
    else {
        return luaL_error(L, "invalid image type specified") ;
    }

    // size changes may not actually affect representations until the image is composited, so...
    // http://stackoverflow.com/a/36451307,
    NSRect targetRect = NSMakeRect(0.0, 0.0, theImage.size.width, theImage.size.height);
    NSImage *newImage = [[NSImage alloc] initWithSize:targetRect.size];
    [newImage lockFocus];
    [theImage drawInRect:targetRect fromRect:targetRect operation:NSCompositingOperationCopy fraction:1.0];
    [newImage unlockFocus];

    NSBitmapImageRep *rep ;
    if (scaleToPixels) {
        // https://gist.github.com/mattstevens/4400775
        rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                      pixelsWide:targetRect.size.width
                                                      pixelsHigh:targetRect.size.height
                                                   bitsPerSample:8
                                                 samplesPerPixel:4
                                                        hasAlpha:YES
                                                        isPlanar:NO
                                                  colorSpaceName:NSCalibratedRGBColorSpace
                                                     bytesPerRow:0
                                                    bitsPerPixel:0];
        [rep setSize:targetRect.size];

        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
        [newImage drawInRect:targetRect fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        NSData *tiffRep = [newImage TIFFRepresentation];
        if (!tiffRep)  return luaL_error(L, "Unable to write image file: Can't create internal representation");

        rep = [NSBitmapImageRep imageRepWithData:tiffRep];
        if (!rep)  return luaL_error(L, "Unable to write image file: Can't wrap internal representation");
    }

    NSData* fileData = [rep representationUsingType:fileType properties:@{}];
    if (!fileData) return luaL_error(L, "Unable to write image file: Can't convert internal representation");

    NSString *result = [fileData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] ;
    [skin pushNSObject:[NSString stringWithFormat:@"data:image/%@;base64,%@", typeLabel.lowercaseString, result]] ;
    return 1 ;
}

/// hs.image:saveToFile(filename, [scale], [filetype]) -> boolean
/// Method
/// Save the hs.image object as an image of type `filetype` to the specified filename.
///
/// Parameters:
///  * filename - the path and name of the file to save.
///  * scale    - an optional boolean, default false, which indicates that the image size (which macOS represents as points) should be scaled to pixels.  For images that have Retina scale representations, this may result in a saved image which is scaled down from the original source.
///  * filetype - optional case-insensitive string paramater specifying the file type to save (default PNG)
///    * PNG  - save in Portable Network Graphics (PNG) format
///    * TIFF - save in Tagged Image File Format (TIFF) format
///    * BMP  - save in Windows bitmap image (BMP) format
///    * GIF  - save in Graphics Image Format (GIF) format
///    * JPEG - save in Joint Photographic Experts Group (JPEG) format
///
/// Returns:
///  * Status - a boolean value indicating success (true) or failure (false)
///
/// Notes:
///  * Saves image at the size in points (or pixels, if `scale` is true) as reported by [hs.image:size()](#size) for the image object
static int saveToFile(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK | LS_TVARARG] ;

    NSImage*  theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSString* filePath = [skin toNSObjectAtIndex:2] ;

    BOOL     scaleToPixels = lua_isboolean(L, 3) ? (BOOL)lua_toboolean(L, 3) : NO ;
    NSString *typeLabel    = @"png" ;
    if (lua_gettop(L) == 3) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TSTRING, LS_TBREAK] ;
        if (lua_type(L, 3) == LUA_TSTRING) {
            typeLabel = [skin toNSObjectAtIndex:3] ;
        }
    } else if (lua_gettop(L) > 3) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBOOLEAN, LS_TSTRING, LS_TBREAK] ;
        typeLabel = [skin toNSObjectAtIndex:4] ;
    } // else it's 2 and we no longer need to check

    NSBitmapImageFileType fileType = NSPNGFileType ;

    if      ([typeLabel compare:@"PNG"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSPNGFileType  ; }
    else if ([typeLabel compare:@"TIFF" options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSTIFFFileType ; }
    else if ([typeLabel compare:@"BMP"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSBMPFileType  ; }
    else if ([typeLabel compare:@"GIF"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSGIFFileType  ; }
    else if ([typeLabel compare:@"JPEG" options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSJPEGFileType ; }
    else if ([typeLabel compare:@"JPG"  options:NSCaseInsensitiveSearch] == NSOrderedSame) { fileType = NSJPEGFileType ; }
    else {
        return luaL_error(L, "hs.image:saveToFile:: invalid file type specified") ;
    }

    BOOL result = false;

    // size changes may not actually affect representations until the image is composited, so...
    // http://stackoverflow.com/a/36451307
    NSRect targetRect = NSMakeRect(0.0, 0.0, theImage.size.width, theImage.size.height);
    NSImage *newImage = [[NSImage alloc] initWithSize:targetRect.size];
    [newImage lockFocus];
    [theImage drawInRect:targetRect fromRect:targetRect operation:NSCompositingOperationCopy fraction:1.0];
    [newImage unlockFocus];

    NSBitmapImageRep *rep ;
    if (scaleToPixels) {
        // https://gist.github.com/mattstevens/4400775
        rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                      pixelsWide:targetRect.size.width
                                                      pixelsHigh:targetRect.size.height
                                                   bitsPerSample:8
                                                 samplesPerPixel:4
                                                        hasAlpha:YES
                                                        isPlanar:NO
                                                  colorSpaceName:NSCalibratedRGBColorSpace
                                                     bytesPerRow:0
                                                    bitsPerPixel:0];
        [rep setSize:targetRect.size];

        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
        [newImage drawInRect:targetRect fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        NSData *tiffRep = [newImage TIFFRepresentation];
        if (!tiffRep)  return luaL_error(L, "Unable to write image file: Can't create internal representation");

        rep = [NSBitmapImageRep imageRepWithData:tiffRep];
        if (!rep)  return luaL_error(L, "Unable to write image file: Can't wrap internal representation");
    }

    NSData* fileData = [rep representationUsingType:fileType properties:@{}];
    if (!fileData) return luaL_error(L, "Unable to write image file: Can't convert internal representation");

    NSError *error;
    if ([fileData writeToFile:[filePath stringByExpandingTildeInPath] options:NSDataWritingAtomic error:&error])
        result = YES ;
    else
        return luaL_error(L, "Unable to write image file: %s", [[error localizedDescription] UTF8String]);

    lua_pushboolean(L, result) ;
    return 1 ;
}

/// hs.image:template([state]) -> imageObject | boolean
/// Method
/// Get or set whether the image is considered a template image.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether or not the image should be a template.
///
/// Returns:
///  * if a parameter is provided, returns the hs.image object; otherwise returns the current value
///
/// Notes:
///  * Template images consist of black and clear colors (and an alpha channel). Template images are not intended to be used as standalone images and are usually mixed with other content to create the desired final appearance.
///  * Images with this flag set to true usually appear lighter than they would with this flag set to false.
static int imageTemplate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSImage *theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, theImage.template) ;
    } else {
        theImage.template = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.image:copy() -> imageObject
/// Method
/// Returns a copy of the image
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new hs.image object
static int copyImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSImage *theImage = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    [skin pushNSObject:[theImage copy]] ;
    return 1 ;
}

#pragma mark - Conversion Extensions

// [skin pushNSObject:NSImage]
// C-API
// Pushes the provided NSImage onto the Lua Stack as a hs.image userdata object
static int NSImage_tolua(lua_State *L, id obj) {
    NSImage *theImage = obj ;
    theImage.cacheMode = NSImageCacheNever ;
    void** imagePtr = lua_newuserdata(L, sizeof(NSImage *));
    *imagePtr = (__bridge_retained void *)theImage;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1 ;
}

static id HSImage_toNSImage(lua_State *L, int idx) {
    void *ptr = luaL_testudata(L, idx, USERDATA_TAG) ;
    if (ptr) {
        return (__bridge NSImage *)*((void **)ptr) ;
    } else {
        return nil ;
    }
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    NSImage *testImage = [[LuaSkin sharedWithState:L] luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSString* theName = [testImage name] ;

    if (!theName) theName = @"" ; // unlike some cases, [NSImage name] apparently returns an actual NULL instead of an empty string...

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, theName, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSImage *image1 = [skin luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSImage *image2 = [skin luaObjectAtIndex:2 toClass:"NSImage"] ;

    return image1 == image2 ;
}

static int userdata_gc(lua_State* L) {
// Get the NSImage so ARC can release it...
    void **thingy = luaL_checkudata(L, 1, USERDATA_TAG) ;
    NSImage* image = (__bridge_transfer NSImage *) *thingy ;
    [image setName:nil] ; // remove from image cache
    [image recache] ;     // invalidate image rep caches
    image = nil;
    return 0 ;
}

static int meta_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [backgroundCallbacks enumerateObjectsUsingBlock:^(NSNumber *ref, __unused BOOL *stop) {
        [skin luaUnref:refTable ref:ref.intValue] ;
    }] ;
    [backgroundCallbacks removeAllObjects] ;
    return 0;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"name",              getImageName},
    {"size",              getImageSize},
    {"template",          imageTemplate},
    {"copy",              copyImage},
    {"croppedCopy",       croppedCopy},
    {"saveToFile",        saveToFile},
    {"encodeAsURLString", encodeAsString},
    {"colorAt",			  colorAt},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL,                NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"imageFromPath",             imageFromPath},
    {"imageFromURL",              imageFromURL},
    {"imageFromASCII",            imageWithContextFromASCII},
//     {"imageWithContextFromASCII", imageWithContextFromASCII},
    {"imageFromName",             imageFromName},
    {"imageFromAppBundle",        imageFromApp},
    {"imageFromMediaFile",        imageFromMediaFile},
    {"iconForFile",               imageForFiles},
    {"iconForFileType",           imageForFileType},
    {"getExifFromPath",           getExifFromPath},

    {NULL,                        NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_libimage(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    pushNSImageNameTable(L); lua_setfield(L, -2, "systemImageNames") ;
    additionalImages(L) ;    lua_setfield(L, -2, "additionalImageNames") ;

    [skin registerPushNSHelper:NSImage_tolua        forClass:"NSImage"] ;
    [skin registerLuaObjectHelper:HSImage_toNSImage forClass:"NSImage" withUserdataMapping:USERDATA_TAG] ;

    if (!missingIconForFile) missingIconForFile = [[NSWorkspace sharedWorkspace] iconForFile:@""] ; // see comment at top

    backgroundCallbacks = [NSMutableSet set] ;
    return 1;
}

