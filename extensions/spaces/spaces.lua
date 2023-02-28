
--- === hs.spaces ===
---
--- This module provides some basic functions for controlling macOS Spaces.
---
--- The functionality provided by this module is considered experimental and subject to change. By using a combination of private APIs and Accessibility hacks (via hs.axuielement), some basic functions for controlling the use of Spaces is possible with Hammerspoon, but there are some limitations and caveats.
---
--- It should be noted that while the functions provided by this module have worked for some time in third party applications and in a previous experimental module that has received limited testing over the last few years, they do utilize some private APIs which means that Apple could change them at any time.
---
--- The functions which allow you to create new spaes, remove spaces, and jump to a specific space utilize `hs.axuielement` and perform accessibility actions through the Dock application to manipulate Mission Control. Because we are essentially directing the Dock to perform User Interactions, there is some visual feedback which we cannot entirely suppress. You can minimize, but not entirely remove, this by enabling "Reduce motion" in System Preferences -> Accessibility -> Display.
---
--- It is recommended that you also enable "Displays have separate Spaces" in System Preferences -> Mission Control.
---
--- This module is a distillation of my previous `hs._asm.undocumented.spaces` module, changes inspired by reviewing the `Yabai` source, and some experimentation with `hs.axuielement`. If you require more sophisticated control, I encourage you to check out https://github.com/koekeishiya/yabai -- it does require some additional setup (changes to SIP, possibly edits to `sudoers`, etc.) but may be worth the extra steps for some power users.

-- TODO:
--    does this work if "Displays have Separate Spaces" isn't checked in System Preferences ->
--        Mission Control? What changes, and can we work around it?
--
--    need working hs.window.filter (or replacement) for pruning windows list and making use of other space windows

-- I think we're probably done with Yabai duplication -- basic functionality desired is present, minus window id pruning
-- +  yabai supports *some* stuff on M1 without injection... investigate
-- *      move window to space               -- according to M1 tracking issue
-- +      ids of windows on other spaces     -- partial; see hs.window.filter comment above

local USERDATA_TAG = "hs.spaces"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
module.watcher     = require(USERDATA_TAG .. ".watcher")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

local axuielement = require("hs.axuielement")
local application = require("hs.application")
local screen      = require("hs.screen")
local inspect     = require("hs.inspect")
local timer       = require("hs.timer")

local host        = require("hs.host")
local fs          = require("hs.fs")
local plist       = require("hs.plist")

-- private variables and methods -----------------------------------------

-- locale handling for buttons representing spaces in Mission Control

local AXExitToDesktop, AXExitToFullscreenDesktop
local getDockExitTemplates = function()
    local localesToSearch = host.locale.preferredLanguages() or {}
    -- make a copy since preferredLanguages uses ls.makeConstantsTable for "friendly" display in console
    localesToSearch = table.move(localesToSearch, 1, #localesToSearch, 1, {})
    table.insert(localesToSearch, host.locale.current())
    local path   = application.applicationsForBundleID("com.apple.dock")[1]:path() .. "/Contents/Resources"

    local locale = ""
    while #localesToSearch > 0 do
        locale = table.remove(localesToSearch, 1):gsub("%-", "_")
        while #locale > 0 do
            if fs.attributes(path .. "/" .. locale .. ".lproj/Accessibility.strings") then break end
            locale = locale:match("^(.-)_?[^_]+$")
        end
        if #locale > 0 then break end
    end

    if #locale == 0 then locale = "en" end -- fallback to english

    local contents = plist.read(path .. "/" .. locale .. ".lproj/Accessibility.strings")
    AXExitToDesktop           = "^" .. contents.AXExitToDesktop:gsub("%%@", "(.-)") .. "$"
    AXExitToFullscreenDesktop = "^" .. contents.AXExitToFullscreenDesktop:gsub("%%@", "(.-)") .. "$"
end

local localeChange_identifier = host.locale.registerCallback(getDockExitTemplates)
getDockExitTemplates() -- set initial values

local spacesNameFromButtonName = function(name)
    return name:match(AXExitToFullscreenDesktop) or name:match(AXExitToDesktop) or name
end

-- now onto the rest of the local functions
local _dockElement
local getDockElement = function()
    -- if the Dock is killed for some reason, its element will be invalid
    if not (_dockElement and _dockElement:isValid()) then
        local dockApp = hs.application.applicationsForBundleID("com.apple.dock")[1]
        _dockElement = axuielement.applicationElement(dockApp)
    end
    return _dockElement
end

local _missionControlGroup
local getMissionControlGroup = function()
    if not (_missionControlGroup and _missionControlGroup:isValid()) then
        _missionControlGroup = nil
        local dockElement = getDockElement()
        for _,v in ipairs(dockElement) do
            if v.AXIdentifier == "mc" then
                _missionControlGroup = v
                break
            end
        end
    end
    return _missionControlGroup
end

local openMissionControl = function()
    local missionControlGroup = getMissionControlGroup()
    if not missionControlGroup then module.toggleMissionControl() end
end

local closeMissionControl = function()
    local missionControlGroup = getMissionControlGroup()
    if missionControlGroup then module.toggleMissionControl() end
end

local findSpacesSubgroup = function(targetIdentifier, screenID)
    local missionControlGroup, initialTime = nil, os.time()
    while not missionControlGroup and (os.time() - initialTime) < 2 do
        missionControlGroup = getMissionControlGroup()
    end
    if not missionControlGroup then
        return nil, "unable to get Mission Control data from the Dock"
    end

    local mcChildren = missionControlGroup:attributeValue("AXChildren") or {}
    local mcDisplay = table.remove(mcChildren)
    while mcDisplay do
        if mcDisplay.AXIdentifier == "mc.display" and mcDisplay.AXDisplayID == screenID then
            break
        end
        mcDisplay = table.remove(mcChildren)
    end
    if not mcDisplay then
        return nil, "no display with specified id found"
    end

    local mcDisplayChildren = mcDisplay:attributeValue("AXChildren") or {}
    local mcSpaces = table.remove(mcDisplayChildren)
    while mcSpaces do
        if mcSpaces.AXIdentifier == "mc.spaces" then
            break
        end
        mcSpaces = table.remove(mcDisplayChildren)
    end
    if not mcSpaces then
        return nil, "unable to locate mc.spaces group for display"
    end

    local mcSpacesChildren = mcSpaces:attributeValue("AXChildren") or {}
    local targetChild = table.remove(mcSpacesChildren)
    while targetChild do
        if targetChild.AXIdentifier == targetIdentifier then break end
        targetChild = table.remove(mcSpacesChildren)
    end
    if not targetChild then
        return nil, string.format("unable to find target %s for display", targetIdentifier)
    end
    return targetChild
end

local waitForMissionControl = function()
    -- delay to make sure Mission Control has stabilized
    local time = timer.secondsSinceEpoch()
    while timer.secondsSinceEpoch() - time < module.MCwaitTime do
        -- twiddle thumbs, calculate more digits of pi, whatever floats your boat...
    end
end

-- Public interface ------------------------------------------------------

--- hs.spaces.data_missionControlAXUIElementData(callback) -> None
--- Function
--- Generate a table containing the results of `hs.axuielement.buildTree` on the Mission Control Accessibility group of the Dock.
---
--- Parameters:
---  * `callback` - a callback function that should expect a table as the results. The table will be formatted as described in the documentation for `hs.axuielement.buildTree`.
---
--- Returns:
---  * None
---
--- Notes:
---  * Like [hs.spaces.data_managedDisplaySpaces](#data_managedDisplaySpaces), this function is not required for general usage of this module; rather it is provided for those who wish to examine the internal data that makes this module possible more closely to see if there might be other information or functionality that they would like to explore.
---  * Getting Accessibility elements for Mission Control is somewhat tricky -- they only exist when the Mission Control display is visible, which is the exact time that you can't examine them. What this function does is trigger Mission Control and then builds a tree of the elements, capturing all of the properties and property values while the elements are valid, closes Mission Control, and then returns the results in a table by invoking the provided callback function.
---    * Note that the `hs.axuielement` objects within the table returned will be invalid by the time you can examine them -- this is why the attributes and values will also be contained in the resulting tree.
---    * Example usage: `hs.spaces.data_missionControlAXUIElementData(function(results) hs.console.clearConsole() ; print(hs.inspect(results)) end)`
module.data_missionControlAXUIElementData = function(callback)
    assert(
        type(callback) == "nil" or type(callback) == "function" or (getmetatable(callback) or {}).__call,
        "callback must be nil or a function"
    )

    openMissionControl()
    local missionControlGroup, initialTime = nil, os.time()
    while not missionControlGroup and (os.time() - initialTime) < 2 do
        missionControlGroup = getMissionControlGroup()
    end
    if not missionControlGroup then
        return nil, "unable to get Mission Control data from the Dock"
    end

    -- delay to make sure Mission Control has stabilized
    waitForMissionControl()

    local tree -- luacheck:ignore
    tree = missionControlGroup:buildTree(function(_, results)
        tree = nil
        closeMissionControl()
        callback(results)
    end)
end

--- hs.spaces.MCwaitTime
--- Variable
--- Specifies how long to delay before performing the accessibility actions for [hs.spaces.gotoSpace](#gotoSpace) and [hs.spaces.removeSpace](#removeSpace)
---
--- Notes:
---  * The above mentioned functions require that the Mission Control accessibility objects be fully formed before the necessary action can be triggered. This variable specifies how long to delay before performing the action to complete the function. Experimentation on my machine has found that 0.3 seconds provides sufficient time for reliable functionality.
---  * If you find that the above mentioned functions do not work reliably with your setup, you can try adjusting this variable upwards -- the down side is that the larger this value is, the longer the Mission Control display is visible before returning the user to what they were working on.
---  * Once you have found a value that works reliably on your system, you can use [hs.spaces.setDefaultMCwaitTime](#setDefaultMCwaitTime) to make it the default value for your system each time the `hs.spaces` module is loaded.
module.MCwaitTime = settings.get(SETTINGS_TAG .. "_MCwaitTime") or 0.3

--- hs.spaces.setDefaultMCwaitTime([time]) -> None
--- Function
--- Sets the initial value for [hs.spaces.MCwaitTime](#MCwaitTime) to be set to when this module first loads.
---
--- Parameters:
---  * `time` - an optional number greater than 0 specifying the initial default for [hs.spaces.MCwaitTime](#MCwaitTime). If you do not specify a value, then the current value of [hs.spaces.MCwaitTime](#MCwaitTime) is used.
---
--- Returns:
---  * None
---
--- Notes:
---  * this function uses the `hs.settings` module to store the default time in the key "hs_spaces_MCwaitTime".
module.setDefaultMCwaitTime = function(qt)
    qt = qt or module.MCwaitTime
    assert(type(qt) == "number" and qt > 0, "default wait time must be a number greater than 0")
    settings.set(SETTINGS_TAG .. "_MCwaitTime", qt)
end

--- hs.spaces.toggleShowDesktop() -> None
--- Function
--- Toggles moving all windows on/off screen to display the desktop underneath.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Desktop setting, the Show Desktop touchbar icon, or the Show Desktop trackpad swipe gesture (Spread with thumb and three fingers).
module.toggleShowDesktop = function() module._coreDesktopNotification("com.apple.showdesktop.awake") end

--- hs.spaces.toggleMissionControl() -> None
--- Function
--- Toggles the Mission Control display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Mission Control setting, the Mission Control touchbar icon, or the Mission Control trackpad swipe gesture (3 or 4 fingers up).
module.toggleMissionControl = function() module._coreDesktopNotification("com.apple.expose.awake") end

--- hs.spaces.toggleAppExpose() -> None
--- Function
--- Toggles the current applications Exposé display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Application Windows setting or the App Exposé trackpad swipe gesture (3 or 4 fingers down).
module.toggleAppExpose = function() module._coreDesktopNotification("com.apple.expose.front.awake") end

--- hs.spaces.toggleLaunchPad() -> None
--- Function
--- Toggles the Launch Pad display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * this is the same functionality as provided by the System Preferences -> Mission Control -> Hot Corners... -> Launch Pad setting, the Launch Pad touchbar icon, or the Launch Pad trackpad swipe gesture (Pinch with thumb and three fingers).
module.toggleLaunchPad = function() module._coreDesktopNotification("com.apple.launchpad.toggle") end

--- hs.spaces.openMissionControl() -> None
--- Function
--- Opens the Mission Control display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Does nothing if the Mission Control display is already visible.
---  * This function uses Accessibility features provided by the Dock to open up Mission Control and is used internally when performing the [hs.spaces.gotoSpace](#gotoSpace), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), and [hs.spaces.removeSpace](#removeSpace) functions.
---  * It is unlikely you will need to invoke this by hand, and the public interface to this function may go away in the future.
module.openMissionControl = openMissionControl

--- hs.spaces.closeMissionControl() -> None
--- Function
--- Opens the Mission Control display
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Does nothing if the Mission Control display is not currently visible.
---  * This function uses Accessibility features provided by the Dock to close Mission Control and is used internally when performing the [hs.spaces.gotoSpace](#gotoSpace), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), and [hs.spaces.removeSpace](#removeSpace) functions.
---  * It is possible to invoke the above mentioned functions and prevent them from auto-closing Mission Control -- this may be useful if you wish to perform multiple actions and want to minimize the visual side-effects. You can then use this function when you are done.
module.closeMissionControl = closeMissionControl

--- hs.spaces.spacesForScreen([screen]) -> table | nil, error
--- Function
--- Returns a table containing the IDs of the spaces for the specified screen in their current order.
---
--- Parameters:
---  * `screen` - an optional screen specification identifying the screen to return the space array for. The screen may be specified by its ID (`hs.screen:id()`), its UUID (`hs.screen:getUUID()`), the string "Main" (a shortcut for `hs.screen.mainScreen()`), the string "Primary" (a shortcut for `hs.screen.primaryScreen()`), or as an `hs.screen` object. If no screen is specified, the screen returned by `hs.screen.mainScreen()` is used.
---
--- Returns:
---  * a table containing space IDs for the spaces for the screen, or nil and an error message if there is an error.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
module.spacesForScreen = function(...)
    local args, screenID = { ... }, nil

    assert(#args < 2, "expected no more than 1 argument")
    if #args > 0 then screenID = args[1] end
    if screenID == nil then
        screenID = screen.mainScreen():getUUID()
    elseif getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:getUUID()
    elseif math.type(screenID) == "integer" then
        for _,v in ipairs(screen.allScreens()) do
            if v:id() == screenID then
                screenID = v:getUUID()
                break
            end
        end
        if math.type(screenID) == "integer" then error("not a valid screen ID") end
    elseif type(screenID) == "string" then
        if screenID:lower() == "main" then
            screenID = screen.mainScreen():getUUID()
        elseif screenID:lower() == "primary" then
            screenID = screen.primaryScreen():getUUID()
        end
    end

    if not (type(screenID) == "string" and #screenID == 36) then
        error("screen must be specified as UUID, screen ID, or hs.screen object")
    end

    local screensHaveSeparateSpaces = module.screensHaveSeparateSpaces()
    if not screensHaveSeparateSpaces then
        for _,v in ipairs(screen.allScreens()) do
            if screenID == v:getUUID() then
                screenID = "Main"
                break
            end
        end
    end

    local managedDisplayData, errMsg = module.data_managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        if managedDisplay["Display Identifier"] == screenID then
            local results = {}
            for _, space in ipairs(managedDisplay.Spaces) do
                table.insert(results, space.ManagedSpaceID)
            end
            return setmetatable(results, { __tostring = inspect })
        end
    end
    return nil, "screen not found in managed displays"
end

--- hs.spaces.allSpaces() -> table | nil, error
--- Function
--- Returns a Kay-Value table containing the IDs of all spaces for all screens.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a key-value table in which the keys are the UUIDs for the current screens and the value for each key is a table of space IDs corresponding to the spaces for that screen. Returns nil and an error message if an error occurs.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
module.allSpaces = function(...)
    local args = { ... }
    assert(#args == 0, "expected no arguments")
    local results = {}
    for _, v in ipairs(screen.allScreens()) do
        local screenID = v:getUUID()
        if screenID then -- allScreens may still report a userdata for a screen that has been disconnected for a short while
            local spacesForScreen, errMsg = module.spacesForScreen(screenID)
            if not spacesForScreen then
                return nil, string.format("%s for %s", errMsg, screenID)
            end
            results[screenID] = spacesForScreen
        end
    end
    return setmetatable(results, { __tostring = inspect })
end

--- hs.spaces.activeSpaceOnScreen([screen]) -> integer | nil, error
--- Function
--- Returns the currently visible (active) space for the specified screen.
---
--- Parameters:
---  * `screen` - an optional screen specification identifying the screen to return the active space for. The screen may be specified by its ID (`hs.screen:id()`), its UUID (`hs.screen:getUUID()`), the string "Main" (a shortcut for `hs.screen.mainScreen()`), the string "Primary" (a shortcut for `hs.screen.primaryScreen()`), or as an `hs.screen` object. If no screen is specified, the screen returned by `hs.screen.mainScreen()` is used.
---
--- Returns:
---  * an integer specifying the ID of the space displayed, or nil and an error message if an error occurs.
module.activeSpaceOnScreen = function(...)
    local args, screenID = { ... }, nil

    assert(#args < 2, "expected no more than 1 argument")
    if #args > 0 then screenID = args[1] end
    if screenID == nil then
        screenID = screen.mainScreen():getUUID()
    elseif getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:getUUID()
    elseif math.type(screenID) == "integer" then
        for _,v in ipairs(screen.allScreens()) do
            if v:id() == screenID then
                screenID = v:getUUID()
                break
            end
        end
        if math.type(screenID) == "integer" then error("not a valid screen ID") end
    elseif type(screenID) == "string" then
        if screenID:lower() == "main" then
            screenID = screen.mainScreen():getUUID()
        elseif screenID:lower() == "primary" then
            screenID = screen.primaryScreen():getUUID()
        end
    end

    if not (type(screenID) == "string" and #screenID == 36) then
        error("screen must be specified as UUID, screen ID, or hs.screen object")
    end

    local screensHaveSeparateSpaces = module.screensHaveSeparateSpaces()
    if not screensHaveSeparateSpaces then
        for _,v in ipairs(screen.allScreens()) do
            if screenID == v:getUUID() then
                screenID = "Main"
                break
            end
        end
    end

    local managedDisplayData, errMsg = module.data_managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        if managedDisplay["Display Identifier"] == screenID then
            for _, space in ipairs(managedDisplay.Spaces) do
                if space.ManagedSpaceID == managedDisplay["Current Space"].ManagedSpaceID then
                    return space.ManagedSpaceID
                end
            end
            return nil, "space not found in specified display"
        end
    end
    return nil, "screen not found in managed displays"
end

--- hs.spaces.activeSpaces() -> table | nil, error
--- Function
--- Returns a key-value table specifying the active spaces for all screens.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a key-value table in which the keys are the UUIDs for the current screens and the value for each key is the space ID of the active space for that display.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
module.activeSpaces = function(...)
    local args = { ... }
    assert(#args == 0, "expected no arguments")
    local results = {}
    for _, v in ipairs(screen.allScreens()) do
        local screenID = v:getUUID()
        if screenID then -- allScreens may still report a userdata for a screen that has been disconnected for a short while
            local activeSpaceID, activeSpaceName = module.activeSpaceOnScreen(screenID)
            if not activeSpaceID then
                return nil, string.format("%s for %s", activeSpaceName, screenID)
            end
            results[screenID] = activeSpaceID
        end
    end
    return setmetatable(results, { __tostring = inspect })
end

--- hs.spaces.spaceDisplay(spaceID) -> string | nil, error
--- Function
--- Returns the screen UUID for the screen that the specified space is on.
---
--- Parameters:
---  * `spaceID` - an integer specifying the ID of the space
---
--- Returns:
---  * a string specifying the UUID of the display the space is on, or nil and error message if an error occurs.
---
--- Notes:
---  * the space does not have to be currently active (visible) to determine which screen the space belongs to.
module.spaceDisplay = function(...)
    local args = { ... }
    assert(#args == 1, "expected 1 argument")
    local spaceID = args[1]
    assert(math.type(spaceID) == "integer", "space id must be an integer")

    local managedDisplayData, errMsg = module.data_managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        for _, space in ipairs(managedDisplay.Spaces) do
            if space.ManagedSpaceID == spaceID then
                local answer = managedDisplay["Display Identifier"]
                if answer == "Main" then answer = screen.mainScreen():getUUID() end

                return answer
            end
        end
    end
    return nil, "space not found in managed displays"
end

--- hs.spaces.spaceType(spaceID) -> string | nil, error
--- Function
--- Returns a string indicating whether the space is a user space or a full screen/tiled application space.
---
--- Parameters:
---  * `spaceID` - an integer specifying the ID of the space
---
--- Returns:
---  * the string "user" if the space is a regular user space, or "fullscreen" if the space is a fullscreen or tiled window pair. Returns nil and an error message if the space does not refer to a valid managed space.
module.spaceType = function(...)
    local args = { ... }
    assert(#args == 1, "expected 1 argument")
    local spaceID = args[1]
    assert(math.type(spaceID) == "integer", "space id must be an integer")

    local managedDisplayData, errMsg = module.data_managedDisplaySpaces()
    if managedDisplayData == nil then return nil, errMsg end
    for _, managedDisplay in ipairs(managedDisplayData) do
        for _, space in ipairs(managedDisplay.Spaces) do
            if space.ManagedSpaceID == spaceID then
                if space.type == 0 then
                    return "user"
                elseif space.type == 4 then
                    return "fullscreen"
                else
                    return nil, string.format("unknown space type %d", space.type)
                end
            end
        end
    end
    return nil, "space not found in managed displays"
end

-- documented in libspaces.m where the core logic of the function resides
local _moveWindowToSpace = module.moveWindowToSpace
module.moveWindowToSpace = function(...)
    local args = { ... }
    if #args > 0 then
        if getmetatable(args[1]) == hs.getObjectMetatable("hs.window") then
            args[1] = args[1]:id()
        end
    end
    return _moveWindowToSpace(table.unpack(args))
end

-- documented in libspaces.m where the core logic of the function resides
local _windowSpaces = module.windowSpaces
module.windowSpaces = function(...)
    local args = { ... }
    if #args > 0 and getmetatable(args[1]) == hs.getObjectMetatable("hs.window") then
        args[1] = args[1]:id()
    end
    return _windowSpaces(table.unpack(args))
end

-- documented in libspaces.m where the core logic of the function resides
local _windowsForSpace = module.windowsForSpace
module.windowsForSpace = function(...)
    local results = { _windowsForSpace(...) }
    local actual = results[1]
    if actual then
        -- prune known Hammerspoon "non-windows" (e.g. canvas)
        local HS = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
        for _, vElement in ipairs(axuielement.applicationElement(HS)) do
            if vElement.AXRole == "AXWindow" and vElement.AXSubrole:match("^AXUnknown") then
                local asHSWindow = vElement:asHSWindow()
                if asHSWindow then
                    local badID = asHSWindow:id()
                    for idx, vID in ipairs(actual) do
                        if vID == badID then
                            table.remove(actual, idx)
                            break
                        end
                    end
                end
            end
        end
    end

    return table.unpack(results)
end

--- hs.spaces.missionControlSpaceNames([closeMC]) -> table | nil, error
--- Function
--- Returns a table containing the space names as they appear in Mission Control associated with their space ID. This is provided for informational purposes only -- all of the functions of this module use the spaceID to insure accuracy.
---
--- Parameters:
---  * `closeMC` - an optional boolean, default true, specifying whether or not the Mission Control display should be closed after adding the new space.
---
--- Returns:
---  * a key-value table in which the keys are the UUIDs for each screen and the value is a key-value table where the screen ID is the key and the Mission Control name of the space is the value.
---
--- Notes:
---  * the table returned has its __tostring metamethod set to `hs.inspect` to simplify inspecting the results when using the Hammerspoon Console.
---  * This function works by opening up the Mission Control display and then grabbing the names from the Accessibility elements created. This is unavoidable. You can  minimize, but not entirely remove, the visual shift to the Mission Control display by by enabling "Reduce motion" in System Preferences -> Accessibility -> Display.
---  * If you intend to perform multiple actions which require the Mission Control display ([hs.spaces.missionControlSpaceNames](#missionControlSpaceNames), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), [hs.spaces.removeSpace](#removeSpace), or [hs.spaces.gotoSpace](#gotoSpace)), you can pass in `false` as the final argument to prevent the automatic closure of the Mission Control display -- this will reduce the visual side-affects to one transition instead of many.
---  * This function attempts to use the localization strings for the Dock application to properly determine the Mission Control names. If you find that it doesn't provide the correct values for your system, please provide the following information when submitting an issue:
---    * the desktop or application name(s) as they appear at the top of the Mission Control screen when you invoke it manually (or with `hs.spaces.toggleMissionControl()` entered into the Hammerspoon console).
---    * the output from the following commands, issued in the Hammerspoon console:
---      * `hs.host.operatingSystemVersionString()`
---      * `hs.host.locale.current()`
---      * `hs.inspect(hs.host.locale.preferredLanguages())`
---      * `hs.inspect(hs.host.locale.details())`
---      * `hs.spaces.screensHaveSeparateSpaces()`
module.missionControlSpaceNames = function(...)
    local args, closeMC = { ... }, true
    assert(#args < 2, "expected no more than 1 arguments")
    if #args == 1 then closeMC = args[1] end
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    local results = {}
    openMissionControl()

    for _, vScreen in ipairs(screen.allScreens()) do
        local screenUUID = vScreen:getUUID()
        local screenID   = vScreen:id()
        if screenUUID and screenID then -- allScreens may still report a userdata for a screen that has been disconnected for a short while
            local spacesForDisplay, mapping = module.spacesForScreen(screenUUID), {}
            local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
            if not mcSpacesList then
                if closeMC then closeMissionControl() end
                return nil, errMsg
            end

            for idx, child in ipairs(mcSpacesList) do
                mapping[spacesForDisplay[idx]] = spacesNameFromButtonName(child.AXDescription)
            end

            results[screenUUID] = mapping
        end
    end

    if closeMC then closeMissionControl() end
    return setmetatable(results, { __tostring = inspect })
end

--- hs.spaces.addSpaceToScreen([screen], [closeMC]) -> true | nil, errMsg
--- Function
--- Adds a new space on the specified screen
---
--- Parameters:
---  * `screen` - an optional screen specification identifying the screen to create the new space on. The screen may be specified by its ID (`hs.screen:id()`), its UUID (`hs.screen:getUUID()`), the string "Main" (a shortcut for `hs.screen.mainScreen()`), the string "Primary" (a shortcut for `hs.screen.primaryScreen()`), or as an `hs.screen` object. If no screen is specified, the screen returned by `hs.screen.mainScreen()` is used.
---  * `closeMC` - an optional boolean, default true, specifying whether or not the Mission Control display should be closed after adding the new space.
---
--- Returns:
---  * true on success; otherwise return nil and an error message
---
--- Notes:
---  * This function creates a new space by opening up the Mission Control display and then programmatically invoking the button to add a new space. This is unavoidable. You can  minimize, but not entirely remove, the visual shift to the Mission Control display by by enabling "Reduce motion" in System Preferences -> Accessibility -> Display.
---  * If you intend to perform multiple actions which require the Mission Control display (([hs.spaces.missionControlSpaceNames](#missionControlSpaceNames), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), [hs.spaces.removeSpace](#removeSpace), or [hs.spaces.gotoSpace](#gotoSpace)), you can pass in `false` as the final argument to prevent the automatic closure of the Mission Control display -- this will reduce the visual side-affects to one transition instead of many.
module.addSpaceToScreen = function(...)
    local args, screenID, closeMC = { ... }, nil, true
    assert(#args < 3, "expected no more than 2 arguments")
    if #args == 1 then
        if type(args[1]) ~= "boolean" then
            screenID = args[1]
        else
            closeMC = args[1]
        end
    elseif #args > 1 then
        screenID, closeMC = table.unpack(args)
    end
    if screenID == nil then
        screenID = screen.mainScreen():id()
    elseif getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
        screenID = screenID:id()
    elseif type(screenID) == "string" then
        if #screenID == 36 then
            for _,v in ipairs(screen.allScreens()) do
                if v:getUUID() == screenID then
                    screenID = v:id()
                    break
                end
            end
        elseif screenID:lower() == "main" then
            screenID = screen.mainScreen():id()
        elseif screenID:lower() == "primary" then
            screenID = screen.primaryScreen():id()
        end
    end

    assert(math.type(screenID) == "integer", "screen id must be an integer")
    assert(type(closeMC) == "boolean", "close flag must be boolean")

    openMissionControl()
    local mcSpacesAdd, errMsg = findSpacesSubgroup("mc.spaces.add", screenID)
    if not mcSpacesAdd then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    local status, errMsg2 = mcSpacesAdd:doAXPress()

    if closeMC then closeMissionControl() end
    if status then
        return true
    else
        return nil, errMsg2
    end
end

--- hs.spaces.gotoSpace(spaceID) -> true | nil, errMsg
--- Function
--- Change to the specified space.
---
--- Parameters:
---  * `spaceID` - an integer specifying the ID of the space
---
--- Returns:
---  * true if the space change was initiated, or nil and an error message if there is an error trying to switch spaces.
---
--- Notes:
---  * This function changes to a space by opening up the Mission Control display and then programmatically invoking the button to activate the space. This is unavoidable. You can  minimize, but not entirely remove, the visual shift to the Mission Control display by by enabling "Reduce motion" in System Preferences -> Accessibility -> Display.
---  * The action of changing to a new space automatically closes the Mission Control display, so unlike ([hs.spaces.missionControlSpaceNames](#missionControlSpaceNames), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), and [hs.spaces.removeSpace](#removeSpace), there is no flag you can specify to leave Mission Control visible. When possible, you should generally invoke this function last if you are performing multiple actions and want to minimize the amount of time the Mission Control display is visible and reduce the visual side affects.
---  * The Accessibility elements required to change to a space are not created until the Mission Control display is fully visible. Because of this, there is a built in delay when invoking this function that can be adjusted by changing the value of [hs.spaces.MCwaitTime](#MCwaitTime).
module.gotoSpace = function(...)
    local args = { ... }
    assert(#args == 1, "expected 1 argument")
    local spaceID = args[1]
    assert(math.type(spaceID) == "integer", "space id must be an integer")

    local screenUUID, screenID = module.spaceDisplay(spaceID), nil
    if not screenUUID then
        return nil, "space not found in managed displays"
    end
    for _, vScreen in ipairs(screen.allScreens()) do
        if screenUUID == vScreen:getUUID() then
            screenID = vScreen:id()
            break
        end
    end

    local count
    for i, vSpace in ipairs(module.spacesForScreen(screenUUID)) do
        if spaceID == vSpace then
            count = i
            break
        end
    end

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        closeMissionControl()
        return nil, errMsg
    end

    -- delay to make sure Mission Control has stabilized
    waitForMissionControl()

    local child = mcSpacesList[count]
    local status, errMsg2 = child:performAction("AXPress")
    if status then
        return true
    else
        closeMissionControl()
        return nil, errMsg2
    end
end


--- hs.spaces.removeSpace(spaceID, [closeMC]) -> true | nil, errMsg
--- Function
--- Removes the specified space.
---
--- Parameters:
---  * `spaceID` - an integer specifying the ID of the space
---  * `closeMC` - an optional boolean, default true, specifying whether or not the Mission Control display should be closed after removing the space.
---
--- Returns:
---  * true if the space removal was initiated, or nil and an error message if there is an error trying to remove the space.
---
--- Notes:
---  * You cannot remove a currently active space -- move to another one first with [hs.spaces.gotoSpace](#gotoSpace).
---  * If a screen has only one user space (i.e. not a full screen application window or tiled set), it cannot be removed.
---  * This function removes a space by opening up the Mission Control display and then programmatically invoking the button to remove the specified space. This is unavoidable. You can  minimize, but not entirely remove, the visual shift to the Mission Control display by by enabling "Reduce motion" in System Preferences -> Accessibility -> Display.
---  * If you intend to perform multiple actions which require the Mission Control display (([hs.spaces.missionControlSpaceNames](#missionControlSpaceNames), [hs.spaces.addSpaceToScreen](#addSpaceToScreen), [hs.spaces.removeSpace](#removeSpace), or [hs.spaces.gotoSpace](#gotoSpace)), you can pass in `false` as the final argument to prevent the automatic closure of the Mission Control display -- this will reduce the visual side-affects to one transition instead of many.
---  * The Accessibility elements required to change to a space are not created until the Mission Control display is fully visible. Because of this, there is a built in delay when invoking this function that can be adjusted by changing the value of [hs.spaces.MCwaitTime](#MCwaitTime).
module.removeSpace = function(...)
    local args, closeMC = { ... }, true
    assert(#args > 0 and #args < 3, "expected between 1 and 2 arguments")
    local spaceID = args[1]
    if #args > 1 then closeMC = args[2] end

    assert(type(closeMC) == "boolean", "close flag must be boolean")
    assert(math.type(spaceID) == "integer", "space id must be an integer")

    local screenUUID, screenID = module.spaceDisplay(spaceID), nil
    if not screenUUID then
        return nil, "space not found in managed displays"
    end
    for _, vScreen in ipairs(screen.allScreens()) do
        if screenUUID == vScreen:getUUID() then
            screenID = vScreen:id()
            break
        end
    end

    local spacesOnScreen = module.spacesForScreen(screenUUID)
    if module.spaceType(spaceID) == "user" then
        local userCount = 0
        for _, vSpace in ipairs(spacesOnScreen) do
            if module.spaceType(vSpace) == "user" then userCount = userCount + 1 end
        end
        if userCount == 1 then
            return nil, "unable to remove the only user space on a screen"
        end

        if module.activeSpaceOnScreen(screenID) == spaceID then
            return nil, "cannot remove a currently active user space"
        end
    end

    local count
    for i, vSpace in ipairs(spacesOnScreen) do
        if spaceID == vSpace then
            count = i
            break
        end
    end

    openMissionControl()
    local mcSpacesList, errMsg = findSpacesSubgroup("mc.spaces.list", screenID)
    if not mcSpacesList then
        if closeMC then closeMissionControl() end
        return nil, errMsg
    end

    -- delay to make sure Mission Control has stabilized
    waitForMissionControl()

    local child = mcSpacesList[count]
    local status, errMsg2 = child:performAction("AXRemoveDesktop")
    if closeMC then closeMissionControl() end
    if status then
        return true
    else
        return nil, errMsg2
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __gc = function(_)
        host.locale.unregisterCallback(localeChange_identifier)
    end
})
