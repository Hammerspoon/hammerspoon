--- === hs.application ===
---
--- Manipulate running applications

local application = require("hs.application.internal")
application.watcher = require("hs.application.watcher")
local timer = require "hs.timer"
local settings = require "hs.settings"

local USERDATA_TAG = "hs.application"
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

local alternateNameMap = {}
local spotlightEnabled = settings.get("HSenableSpotlightForNameSearches")

-- internal search tool for alternate names
local realNameFor = function(value, exact)
    if type(value) ~= "string" then
        error('hint must be a string', 2)
    end
    if not exact then
        local results = {}
        for k, v in pairs(alternateNameMap) do
            if k:lower():find(value:lower()) then
                -- I can foresee someday wanting to know how often a match was found, so make it a
                -- number rather than a boolean so I can cut & paste this
                results[v] = (results[v] or 0) + 1
            end
        end
        local returnedResults = {}
        for k,_ in pairs(results) do
            table.insert(returnedResults, k:match("^(.*)%.app$") or k)
        end
        return table.unpack(returnedResults)
    else
        local realName = alternateNameMap[value]
        -- hs.application functions/methods do not like the .app at the end of application
        -- bundles, so remove it.
        return realName and realName:match("^(.*)%.app$") or realName
    end
end

local type,pairs,ipairs=type,pairs,ipairs
local tunpack,tpack,tsort=table.unpack,table.pack,table.sort

--- hs.application:visibleWindows() -> win[]
--- Method
--- Returns only the app's windows that are visible.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing zero or more hs.window objects
function objectMT.visibleWindows(self)
  local r={}
  if self:isHidden() then return r -- do not check :isHidden for every window
  else for _,w in ipairs(self:allWindows()) do if not w:isMinimized() then r[#r+1]=w end end end
  return r
end

--- hs.application:activate([allWindows]) -> bool
--- Method
--- Tries to activate the app (make its key window focused) and returns whether it succeeded; if allWindows is true, all windows of the application are brought forward as well.
---
--- Parameters:
---  * allWindows - If true, all windows of the application will be brought to the front. Otherwise, only the application's key window will. Defaults to false.
---
--- Returns:
---  * A boolean value indicating whether or not the application could be activated
function objectMT.activate(self, allWindows)
  allWindows=allWindows and true or false
  if self:isUnresponsive() then return false end
  local win = self:focusedWindow()
  if win then
    return win:becomeMain() and self:_bringtofront(allWindows)
  else
    return self:_activate(allWindows)
  end
end

--- hs.application:name()
--- Method
--- Alias for [`hs.application:title()`](#title)
objectMT.name=objectMT.title

--- hs.application.get(hint) -> hs.application object
--- Constructor
--- Gets a running application
---
--- Parameters:
---  * hint - search criterion for the desired application; it can be:
---    - a pid number as per `hs.application:pid()`
---    - a bundle ID string as per `hs.application:bundleID()`
---    - an application name string as per `hs.application:name()`
---
--- Returns:
---  * an hs.application object for a running application that matches the supplied search criterion, or `nil` if not found
---
--- Notes:
---  * see also `hs.application.find`
function application.get(hint)
  return tpack(application.find(hint,true),nil)[1] -- just to be sure, discard extra results
end

--- hs.application.find(hint) -> hs.application object(s)
--- Constructor
--- Finds running applications
---
--- Parameters:
---  * hint - search criterion for the desired application(s); it can be:
---    - a pid number as per `hs.application:pid()`
---    - a bundle ID string as per `hs.application:bundleID()`
---    - a string pattern that matches (via `string.find`) the application name as per `hs.application:name()` (for convenience, the matching will be done on lowercased strings)
---    - a string pattern that matches (via `string.find`) the application's window title per `hs.window:title()` (for convenience, the matching will be done on lowercased strings)
---
--- Returns:
---  * one or more hs.application objects for running applications that match the supplied search criterion, or `nil` if none found
---
--- Notes:
---  * If multiple results are found, this function will return multiple values. See [https://www.lua.org/pil/5.1.html](https://www.lua.org/pil/5.1.html) for more information on how to work with this
---  * for convenience you can call this as `hs.application(hint)`
---  * use this function when you don't know the exact name of an application you're interested in, i.e.
---    from the console: `hs.application'term' --> hs.application: iTerm2 (0x61000025fb88)  hs.application: Terminal (0x618000447588)`.
---    But be careful when using it in your `init.lua`: `terminal=hs.application'term'` will assign either "Terminal" or "iTerm2" arbitrarily (or even,
---    if neither are running, any other app with a window that happens to have "term" in its title); to make sure you get the right app in your scripts,
---    use `hs.application.get` with the exact name: `terminal=hs.application.get'Terminal' --> "Terminal" app, or nil if it's not running`
---
--- Usage:
--- -- by pid
--- hs.application(42):name() --> Finder
--- -- by bundle id
--- hs.application'com.apple.Safari':name() --> Safari
--- -- by name
--- hs.application'chrome':name() --> Google Chrome
--- -- by window title
--- hs.application'bash':name() --> Terminal
local findSpotlightWarningGiven = false
function application.find(hint,exact)
  if hint==nil then return end
  local typ=type(hint)
  if typ=='number' then return application.applicationForPID(hint)
  elseif typ~='string' then error('hint must be a number or string',2) end
  local r=application.applicationsForBundleID(hint)
  if #r>0 then return tunpack(r) end
  local apps=application.runningApplications()

  if exact then for _,a in ipairs(apps) do if a:name()==hint then r[#r+1]=a end end
  else for _,a in ipairs(apps) do local aname=a:name() if aname and aname:lower():find(hint:lower()) then r[#r+1]=a end end end

  if spotlightEnabled then
      for _, v in ipairs(table.pack(realNameFor(hint, exact))) do
          for _, a in ipairs(apps) do
              if a:name() ~= nil and v:lower() == a:name():lower() then
                  r[#r+1]=a
              end
          end
      end
  elseif type(spotlightEnabled) == "nil" and not findSpotlightWarningGiven then
      findSpotlightWarningGiven = true
      print("-- Some applications have alternate names which can also be checked if you enable Spotlight support with `hs.application.enableSpotlightForNameSearches(true)`.")
  end

  tsort(r,function(a,b)return a:kind()>b:kind()end) -- gui apps first
  if exact or #r>0 then return tunpack(r) end

  r=tpack(hs.window.find(hint))
  local rs={} for _,w in ipairs(r) do rs[w:application()]=true end -- :toSet
  for a in pairs(rs) do r[#r+1]=a end -- and back, no dupes
  if #r>0 then return tunpack(r) end
end

--- hs.application:findWindow(titlePattern) -> hs.window object(s)
--- Method
--- Finds windows from this application
---
--- Parameters:
---  * titlePattern - a string pattern that matches (via `string.find`) the window title(s) as per `hs.window:title()` (for convenience, the matching will be done on lowercased strings)
---
--- Returns:
---  * one or more hs.window objects belonging to this application that match the supplied search criterion, or `nil` if none found

function objectMT.findWindow(self, hint)
  return hs.window.find(hint,false,self:allWindows())
end

--- hs.application:getWindow(title) -> hs.window object
--- Method
--- Gets a specific window from this application
---
--- Parameters:
---  * title - the desired window's title string as per `hs.window:title()`
---
--- Returns:
---  * the desired hs.window object belonging to this application, or `nil` if not found
function objectMT.getWindow(self, hint)
  return tpack(hs.window.find(hint,true,self:allWindows()),nil)[1]
end

--- hs.application.open(app[, wait, [waitForFirstWindow]]) -> hs.application object
--- Constructor
--- Launches an application, or activates it if it's already running
---
--- Parameters:
---  * app - a string describing the application to open; it can be:
---    - the application's name as per `hs.application:name()`
---    - the full path to an application on disk (including the `.app` suffix)
---    - the application's bundle ID as per `hs.application:bundleID()`
---  * wait - (optional) the maximum number of seconds to wait for the app to be launched, if not already running; if omitted, defaults to 0;
---   if the app takes longer than this to launch, this function will return `nil`, but the app will still launch
---  * waitForFirstWindow - (optional) if `true`, additionally wait until the app has spawned its first window (which usually takes a bit longer)
---
--- Returns:
---  * the `hs.application` object for the launched or activated application; `nil` if not found
---
--- Notes:
---  * the `wait` parameter will *block all Hammerspoon activity* in order to return the application object "synchronously"; only use it if you
---    a) have no time-critical event processing happening elsewhere in your `init.lua` and b) need to act on the application object, or on
---    its window(s), right away
---  * when launching a "windowless" app (background daemon, menulet, etc.) make sure to omit `waitForFirstWindow`
function application.open(app,wait,waitForWindow)
  if type(app)~='string' then error('app must be a string',2) end
  if wait and type(wait)~='number' then error('wait must be a number',2) end
  local r=application.launchOrFocus(app) or application.launchOrFocusByBundleID(app)
  if not r then return end
  r=nil
  wait=(wait or 0)*1000000
  local CHECK_INTERVAL=100000
  repeat
    r=r or application.get(app)
    if r and (not waitForWindow or r:mainWindow()) then return r end
    timer.usleep(math.min(wait,CHECK_INTERVAL)) wait=wait-CHECK_INTERVAL
  until wait<=0
  return r
end

--- hs.application.menuGlyphs
--- Variable
--- A table containing UTF8 representations of the defined key glyphs used in Menus for keybaord shortcuts which are presented pictorially rather than as text (arrow keys, return key, etc.)
---
--- These glyphs are indexed numerically where the numeric index matches a possible value for the AXMenuItemCmdGlyph key of an entry returned by `hs.application.getMenus`.  If the AXMenuItemCmdGlyph field is non-numeric, then no glyph is used in the presentation of the keyboard shortcut for a menu item.
---
--- The following glyphs are defined:
---  * "⇥",  -- kMenuTabRightGlyph, 0x02, Tab to the right key (for left-to-right script systems)
---  * "⇤",  -- kMenuTabLeftGlyph, 0x03, Tab to the left key (for right-to-left script systems)
---  * "⌤",   -- kMenuEnterGlyph, 0x04, Enter key
---  * "⇧",  -- kMenuShiftGlyph, 0x05, Shift key
---  * "⌃",   -- kMenuControlGlyph, 0x06, Control key
---  * "⌥",  -- kMenuOptionGlyph, 0x07, Option key
---  * "␣",    -- kMenuSpaceGlyph, 0x09, Space (always glyph 3) key
---  * "⌦",  -- kMenuDeleteRightGlyph, 0x0A, Delete to the right key (for right-to-left script systems)
---  * "↩",  -- kMenuReturnGlyph, 0x0B, Return key (for left-to-right script systems)
---  * "↪",  -- kMenuReturnR2LGlyph, 0x0C, Return key (for right-to-left script systems)
---  * "",   -- kMenuPencilGlyph, 0x0F, Pencil key
---  * "↓",   -- kMenuDownwardArrowDashedGlyph, 0x10, Downward dashed arrow key
---  * "⌘",  -- kMenuCommandGlyph, 0x11, Command key
---  * "✓",   -- kMenuCheckmarkGlyph, 0x12, Checkmark key
---  * "⃟",   -- kMenuDiamondGlyph, 0x13, Diamond key
---  * "",   -- kMenuAppleLogoFilledGlyph, 0x14, Apple logo key (filled)
---  * "⌫",  -- kMenuDeleteLeftGlyph, 0x17, Delete to the left key (for left-to-right script systems)
---  * "←",  -- kMenuLeftArrowDashedGlyph, 0x18, Leftward dashed arrow key
---  * "↑",   -- kMenuUpArrowDashedGlyph, 0x19, Upward dashed arrow key
---  * "→",   -- kMenuRightArrowDashedGlyph, 0x1A, Rightward dashed arrow key
---  * "⎋",  -- kMenuEscapeGlyph, 0x1B, Escape key
---  * "⌧",  -- kMenuClearGlyph, 0x1C, Clear key
---  * "『",  -- kMenuLeftDoubleQuotesJapaneseGlyph, 0x1D, Unassigned (left double quotes in Japanese)
---  * "』",  -- kMenuRightDoubleQuotesJapaneseGlyph, 0x1E, Unassigned (right double quotes in Japanese)
---  * "␢",   -- kMenuBlankGlyph, 0x61, Blank key
---  * "⇞",   -- kMenuPageUpGlyph, 0x62, Page up key
---  * "⇪",  -- kMenuCapsLockGlyph, 0x63, Caps lock key
---  * "←",  -- kMenuLeftArrowGlyph, 0x64, Left arrow key
---  * "→",   -- kMenuRightArrowGlyph, 0x65, Right arrow key
---  * "↖",  -- kMenuNorthwestArrowGlyph, 0x66, Northwest arrow key
---  * "﹖",  -- kMenuHelpGlyph, 0x67, Help key
---  * "↑",   -- kMenuUpArrowGlyph, 0x68, Up arrow key
---  * "↘",  -- kMenuSoutheastArrowGlyph, 0x69, Southeast arrow key
---  * "↓",   -- kMenuDownArrowGlyph, 0x6A, Down arrow key
---  * "⇟",   -- kMenuPageDownGlyph, 0x6B, Page down key
---  * "",  -- kMenuContextualMenuGlyph, 0x6D, Contextual menu key
---  * "⌽",  -- kMenuPowerGlyph, 0x6E, Power key
---  * "F1",  -- kMenuF1Glyph, 0x6F, F1 key
---  * "F2",  -- kMenuF2Glyph, 0x70, F2 key
---  * "F3",  -- kMenuF3Glyph, 0x71, F3 key
---  * "F4",  -- kMenuF4Glyph, 0x72, F4 key
---  * "F5",  -- kMenuF5Glyph, 0x73, F5 key
---  * "F6",  -- kMenuF6Glyph, 0x74, F6 key
---  * "F7",  -- kMenuF7Glyph, 0x75, F7 key
---  * "F8",  -- kMenuF8Glyph, 0x76, F8 key
---  * "F9",  -- kMenuF9Glyph, 0x77, F9 key
---  * "F10", -- kMenuF10Glyph, 0x78, F10 key
---  * "F11", -- kMenuF11Glyph, 0x79, F11 key
---  * "F12", -- kMenuF12Glyph, 0x7A, F12 key
---  * "F13", -- kMenuF13Glyph, 0x87, F13 key
---  * "F14", -- kMenuF14Glyph, 0x88, F14 key
---  * "F15", -- kMenuF15Glyph, 0x89, F15 key
---  * "⎈",  -- kMenuControlISOGlyph, 0x8A, Control key (ISO standard)
---  * "⏏",   -- kMenuEjectGlyph, 0x8C, Eject key (available on Mac OS X 10.2 and later)
---  * "英数", -- kMenuEisuGlyph, 0x8D, Japanese eisu key (available in Mac OS X 10.4 and later)
---  * "かな", -- kMenuKanaGlyph, 0x8E, Japanese kana key (available in Mac OS X 10.4 and later)
---  * "F16", -- kMenuF16Glyph, 0x8F, F16 key (available in SnowLeopard and later)
---  * "F17", -- kMenuF16Glyph, 0x90, F17 key (available in SnowLeopard and later)
---  * "F18", -- kMenuF16Glyph, 0x91, F18 key (available in SnowLeopard and later)
---  * "F19", -- kMenuF16Glyph, 0x92, F19 key (available in SnowLeopard and later)
---
--- Notes:
---  * a `__tostring` metamethod is provided for this table so you can view its current contents by typing `hs.application.menuGlyphs` into the Hammerspoon console.
---  * This table is provided as a variable so that you can change any representation if you feel you know of a better or more appropriate one for you usage at runtime.
---
---  * The glyphs provided are defined in the Carbon framework headers in the Menus.h file, located (as of 10.11) at /System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Headers/Menus.h.
---  * The following constants are defined in Menus.h, but do not seem to correspond to a visible UTF8 character or well defined representation that I could discover.  If you believe that you know of a (preferably sanctioned by Apple) proper visual representation, please submit an issue detailing it at the Hammerspoon repository on Github.
---    * kMenuNullGlyph, 0x00, Null (always glyph 1)
---    * kMenuNonmarkingReturnGlyph, 0x0D, Nonmarking return key
---    * kMenuParagraphKoreanGlyph, 0x15, Unassigned (paragraph in Korean)
---    * kMenuTrademarkJapaneseGlyph, 0x1F, Unassigned (trademark in Japanese)
---    * kMenuAppleLogoOutlineGlyph, 0x6C, Apple logo key (outline)
application.menuGlyphs = setmetatable({
  [2] = "⇥",     -- kMenuTabRightGlyph, 0x02, Tab to the right key (for left-to-right script systems)
  [3] = "⇤",     -- kMenuTabLeftGlyph, 0x03, Tab to the left key (for right-to-left script systems)
  [4] = "⌤",     -- kMenuEnterGlyph, 0x04, Enter key
  [5] = "⇧",     -- kMenuShiftGlyph, 0x05, Shift key
  [6] = "⌃",     -- kMenuControlGlyph, 0x06, Control key
  [7] = "⌥",     -- kMenuOptionGlyph, 0x07, Option key
  [9] = "␣",      -- kMenuSpaceGlyph, 0x09, Space (always glyph 3) key
  [10] = "⌦",    -- kMenuDeleteRightGlyph, 0x0A, Delete to the right key (for right-to-left script systems)
  [11] = "↩",    -- kMenuReturnGlyph, 0x0B, Return key (for left-to-right script systems)
  [12] = "↪",    -- kMenuReturnR2LGlyph, 0x0C, Return key (for right-to-left script systems)
  [15] = "",    -- kMenuPencilGlyph, 0x0F, Pencil key
  [16] = "↓",     -- kMenuDownwardArrowDashedGlyph, 0x10, Downward dashed arrow key
  [17] = "⌘",    -- kMenuCommandGlyph, 0x11, Command key
  [18] = "✓",     -- kMenuCheckmarkGlyph, 0x12, Checkmark key
  [19] = "◇",     -- kMenuDiamondGlyph, 0x13, Diamond key
  [20] = "",     -- kMenuAppleLogoFilledGlyph, 0x14, Apple logo key (filled)
  [23] = "⌫",    -- kMenuDeleteLeftGlyph, 0x17, Delete to the left key (for left-to-right script systems)
  [24] = "←",    -- kMenuLeftArrowDashedGlyph, 0x18, Leftward dashed arrow key
  [25] = "↑",     -- kMenuUpArrowDashedGlyph, 0x19, Upward dashed arrow key
  [26] = "→",     -- kMenuRightArrowDashedGlyph, 0x1A, Rightward dashed arrow key
  [27] = "⎋",    -- kMenuEscapeGlyph, 0x1B, Escape key
  [28] = "⌧",    -- kMenuClearGlyph, 0x1C, Clear key
  [29] = "『",    -- kMenuLeftDoubleQuotesJapaneseGlyph, 0x1D, Unassigned (left double quotes in Japanese)
  [30] = "』",    -- kMenuRightDoubleQuotesJapaneseGlyph, 0x1E, Unassigned (right double quotes in Japanese)
  [97] = "␢",     -- kMenuBlankGlyph, 0x61, Blank key
  [98] = "⇞",     -- kMenuPageUpGlyph, 0x62, Page up key
  [99] = "⇪",    -- kMenuCapsLockGlyph, 0x63, Caps lock key
  [100] = "←",   -- kMenuLeftArrowGlyph, 0x64, Left arrow key
  [101] = "→",    -- kMenuRightArrowGlyph, 0x65, Right arrow key
  [102] = "↖",   -- kMenuNorthwestArrowGlyph, 0x66, Northwest arrow key
  [103] = "﹖",   -- kMenuHelpGlyph, 0x67, Help key
  [104] = "↑",    -- kMenuUpArrowGlyph, 0x68, Up arrow key
  [105] = "↘",   -- kMenuSoutheastArrowGlyph, 0x69, Southeast arrow key
  [106] = "↓",    -- kMenuDownArrowGlyph, 0x6A, Down arrow key
  [107] = "⇟",    -- kMenuPageDownGlyph, 0x6B, Page down key
  [109] = "",   -- kMenuContextualMenuGlyph, 0x6D, Contextual menu key
  [110] = "⌽",   -- kMenuPowerGlyph, 0x6E, Power key
  [111] = "F1",   -- kMenuF1Glyph, 0x6F, F1 key
  [112] = "F2",   -- kMenuF2Glyph, 0x70, F2 key
  [113] = "F3",   -- kMenuF3Glyph, 0x71, F3 key
  [114] = "F4",   -- kMenuF4Glyph, 0x72, F4 key
  [115] = "F5",   -- kMenuF5Glyph, 0x73, F5 key
  [116] = "F6",   -- kMenuF6Glyph, 0x74, F6 key
  [117] = "F7",   -- kMenuF7Glyph, 0x75, F7 key
  [118] = "F8",   -- kMenuF8Glyph, 0x76, F8 key
  [119] = "F9",   -- kMenuF9Glyph, 0x77, F9 key
  [120] = "F10",  -- kMenuF10Glyph, 0x78, F10 key
  [121] = "F11",  -- kMenuF11Glyph, 0x79, F11 key
  [122] = "F12",  -- kMenuF12Glyph, 0x7A, F12 key
  [135] = "F13",  -- kMenuF13Glyph, 0x87, F13 key
  [136] = "F14",  -- kMenuF14Glyph, 0x88, F14 key
  [137] = "F15",  -- kMenuF15Glyph, 0x89, F15 key
  [138] = "⎈",   -- kMenuControlISOGlyph, 0x8A, Control key (ISO standard)
  [140] = "⏏",   -- kMenuEjectGlyph, 0x8C, Eject key (available on Mac OS X 10.2 and later)
  [141] = "英数", -- kMenuEisuGlyph, 0x8D, Japanese eisu key (available in Mac OS X 10.4 and later)
  [142] = "かな", -- kMenuKanaGlyph, 0x8E, Japanese kana key (available in Mac OS X 10.4 and later)
  [143] = "F16",  -- kMenuF16Glyph, 0x8F, F16 key (available in SnowLeopard and later)
  [144] = "F17",  -- kMenuF16Glyph, 0x90, F17 key (available in SnowLeopard and later)
  [145] = "F18",  -- kMenuF16Glyph, 0x91, F18 key (available in SnowLeopard and later)
  [146] = "F19",  -- kMenuF16Glyph, 0x92, F19 key (available in SnowLeopard and later)
}, {
  __tostring = function(self)
    local result = ""
    for k, v in require("hs.fnutils").sortByKeys(self) do
      result = result..string.format("%4d %s\n", k, v)
    end
    return result
  end,
})

-- handles updates to the alternateNameMap table
local modifyNameMap = function(info, add)
    for _, item in ipairs(info) do
        local applicationName = item.kMDItemFSName
        for _, alt in ipairs(item.kMDItemAlternateNames or {}) do
            alternateNameMap[alt:match("^(.*)%.app$") or alt] = add and applicationName or nil
        end
    end
end

-- local var to hold spotlight query userdata to catch updates
local spotlightWatcher

-- starts the spotlight query to get the alternate names for applications
local buildAlternateNameMap = function()
    if spotlightWatcher then -- force a rebuild if it's already running
        spotlightWatcher:stop()
        spotlightWatcher = nil
        alternateNameMap = {}
        application._alternateNameMap = alternateNameMap
    end
    spotlightWatcher = require"hs.spotlight".new()
    spotlightWatcher:queryString([[ kMDItemContentType = "com.apple.application-bundle" ]])
                    :callbackMessages("didUpdate", "inProgress")
                    :setCallback(function(_, _, info)
                        if info then -- shouldn't be nil for didUpdate and inProgress, but check anyways
                            -- all three can occur in either message, so check them all!
                            if info.kMDQueryUpdateAddedItems   then
                                modifyNameMap(info.kMDQueryUpdateAddedItems,   true)
                            end
                            if info.kMDQueryUpdateChangedItems then
                                modifyNameMap(info.kMDQueryUpdateChangedItems, true)
                            end
                            if info.kMDQueryUpdateRemovedItems then
                                modifyNameMap(info.kMDQueryUpdateRemovedItems, false)
                            end
                        end
                    end):start()
end

--- hs.application.enableSpotlightForNameSearches([state]) -> boolean
--- Function
--- Get or set whether Spotlight should be used to find alternate names for applications.
---
--- Parameters:
---  * `state` - an optional boolean specifying whether or not Spotlight should be used to try and determine alternate application names for `hs.application.find` and similar functions.
---
--- Returns:
---  * the current, possibly changed, state
---
--- Notes:
---  * This setting is persistent across reloading and restarting Hammerspoon.
---  * If this was set to true and you set it to true again, it will purge the alternate name map and rebuild it from scratch.
---  * You can disable Spotlight alternate name mapping by setting this value to false or nil. If you set this to false, then the notifications indicating that more results might be possible if Spotlight is enabled will be suppressed.
application.enableSpotlightForNameSearches = function(...)
    local args = table.pack(...)
    if args.n > 0 then
        if args[1] then
            settings.set("HSenableSpotlightForNameSearches", true)
            spotlightEnabled = true
            buildAlternateNameMap()
        else
            settings.set("HSenableSpotlightForNameSearches", args[1])
            spotlightEnabled = args[1]
            if spotlightWatcher then
                spotlightWatcher:stop()
                spotlightWatcher = nil
            end
            alternateNameMap = {}
            application._alternateNameMap = alternateNameMap
        end
    end
    return settings.get("HSenableSpotlightForNameSearches")
end

-- if the setting is set, then go ahead and start the build process
if spotlightEnabled then buildAlternateNameMap() end

do
  local mt=getmetatable(application)
  -- whoever gets it first (window vs application)
  if not mt.__call then mt.__call=function(t,...) return t.find(...) end end
end

application._alternateNameMap = alternateNameMap

return application
