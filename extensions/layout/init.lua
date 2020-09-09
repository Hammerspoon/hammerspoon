--- === hs.layout ===
---
--- Window layout manager
---
--- This extension allows you to trigger window placement/sizing to a number of windows at once

local layout = {}
local geometry = require("hs.geometry")
local fnutils = require("hs.fnutils")
local screen = require("hs.screen")
local window = require("hs.window")
local application = require("hs.application")

--- hs.layout.left25
--- Constant
--- A unit rect which will make a window occupy the left 25% of a screen
layout.left25 = geometry.rect(0, 0, 0.25, 1)

--- hs.layout.left30
--- Constant
--- A unit rect which will make a window occupy the left 30% of a screen
layout.left30 = geometry.rect(0, 0, 0.3, 1)

--- hs.layout.left50
--- Constant
--- A unit rect which will make a window occupy the left 50% of a screen
layout.left50 = geometry.rect(0, 0, 0.5, 1)

--- hs.layout.left70
--- Constant
--- A unit rect which will make a window occupy the left 70% of a screen
layout.left70 = geometry.rect(0, 0, 0.7, 1)

--- hs.layout.left75
--- Constant
--- A unit rect which will make a window occupy the left 75% of a screen
layout.left75 = geometry.rect(0, 0, 0.75, 1)

--- hs.layout.right25
--- Constant
--- A unit rect which will make a window occupy the right 25% of a screen
layout.right25 = geometry.rect(0.75, 0, 0.25, 1)

--- hs.layout.right30
--- Constant
--- A unit rect which will make a window occupy the right 30% of a screen
layout.right30 = geometry.rect(0.7, 0, 0.3, 1)

--- hs.layout.right50
--- Constant
--- A unit rect which will make a window occupy the right 50% of a screen
layout.right50 = geometry.rect(0.5, 0, 0.5, 1)

--- hs.layout.right70
--- Constant
--- A unit rect which will make a window occupy the right 70% of a screen
layout.right70 = geometry.rect(0.3, 0, 0.7, 1)

--- hs.layout.right75
--- Constant
--- A unit rect which will make a window occupy the right 75% of a screen
layout.right75 = geometry.rect(0.25, 0, 0.75, 1)

--- hs.layout.maximized
--- Constant
--- A unit rect which will make a window occupy all of a screen
layout.maximized = geometry.rect(0, 0, 1, 1)

--- hs.layout.apply(table[, windowTitleComparator])
--- Function
--- Applies a layout to applications/windows
---
--- Parameters:
---  * table - A table describing your desired layout. Each element in the table should be another table describing a set of windows to match, and their desired size/position. The fields in each of these tables are:
---   * A string containing an application name, or an `hs.application` object, or nil
---   * A string containing a window title, or an `hs.window` object, or a function, or nil
---   * A string containing a screen name, or an `hs.screen` object, or a function that accepts no parameters and returns an `hs.screen` object, or nil to select the first available screen
---   * A Unit rect, or a function which is called for each window and returns a unit rect (see `hs.window.moveToUnit()`). The function should accept one parameter, which is the window object.
---   * A Frame rect, or a function which is called for each window and returns a frame rect (see `hs.screen:frame()`). The function should accept one parameter, which is the window object.
---   * A Full-frame rect, of a function which is called for each window and returns a full-frame rect (see `hs.screen:fullFrame()`). The function should accept one parameter, which is the window object.
---  * windowTitleComparator - (optional) Function to use for window title comparison. It is called with two string arguments (below) and its return value is evaluated as a boolean. If no comparator is provided, the '==' operator is used
---   * windowTitle: The `:title()` of the window object being examined
---   * layoutWindowTitle: The window title string (second field) specified in each element of the layout table
---   * Optionally a final element, the key "options" and a table value that can contain the following keys:
---     * `absolute_x`: A boolean indicating that the x value in a frame rect above, is an absolute co-ordinate (ie useful for negative absolute co-ordinates)
---     * `absolute_y`: A boolean indicating that the y value in a frame rect above, is an absolute co-ordinate (ie useful for negative absolute co-ordinates)
---
--- Returns:
---  * None
---
--- Notes:
---  * If the application name argument is nil, window titles will be matched regardless of which app they belong to
---  * If the window title argument is nil, all windows of the specified application will be matched
---  * If the window title argument is a function, the function will be called with the application name argument (which may be nil), and should return a table of `hs.window` objects (even if there is only one window it must be in a table)
---  * You can specify both application name and window title if you want to match only one window of a particular application
---  * If you specify neither application name or window title, no windows will be matched :)
---  * Monitor name is a string, as found in `hs.screen:name()` or `hs.screen:getUUID()`. You can also pass an `hs.screen` object, or a function that returns an `hs.screen` object. If you pass nil, the first screen will be selected
---  * The final three arguments use `hs.geometry.rect()` objects to describe the desired position and size of matched windows:
---    * Unit rect will be passed to `hs.window.moveToUnit()`
---    * Frame rect will be passed to `hs.window.setFrame()` (including menubar and dock)
---    * Full-frame rect will be passed to `hs.window.setFrame()` (ignoring menubar and dock)
---  * If either the x or y components of frame/full-frame rect are negative, they will be applied as offsets against the opposite edge of the screen (e.g. If x is -100 then the left edge of the window will be 100 pixels from the right edge of the screen)
---  * Only one of the rect arguments will apply to any matched windows. If you specify more than one, the first will win
---  * An example usage:
---
---     ```layout1 = {
---         {"Mail", nil, "Color LCD", hs.layout.maximized, nil, nil},
---         {"Safari", nil, "Thunderbolt Display", hs.layout.maximized, nil, nil},
---         {"iTunes", "iTunes", "Color LCD", hs.layout.maximized, nil, nil},
---         {"iTunes", "MiniPlayer", "Color LCD", nil, nil, hs.geometry.rect(0, -48, 400, 48)},
---       }```
---  * An example of a function that works well as a `windowTitleComparator` is the Lua built-in `string.match`, which uses Lua Patterns to match strings
function layout.apply(theLayout, windowTitleComparator)
-- Layout parameter should be a table where each row takes the form of:
--  {"App name", "Window name","Display Name"/"hs.screen object", "unitrect", "framerect", "fullframerect"},
--  First three items in each row are strings (although the display name can also be an hs.screen object, or nil)
--  Second three items are rects that specify the position of the window. The first one that is
--   not nil, wins.
--  unitrect is a rect passed to window:moveToUnit()
--  framerect is a rect passed to window:setFrame()
--      If either the x or y components of framerect are negative, they will be applied as
--      offsets from the width or height of screen:frame(), respectively
--  fullframerect is a rect passed to window:setFrame()
--      If either the x or y components of fullframerect are negative, they will be applied
--      as offsets from the width or height of screen:fullFrame(), respectively

    if not windowTitleComparator then
        windowTitleComparator = function(windowTitle, layoutWindowTitle)
            return windowTitle == layoutWindowTitle
        end
    end
    for _,_row in pairs(theLayout) do
        local app = nil
        local wins = nil
        local display = nil
        local displaypoint = nil
        local unit = _row[4]
        local frame = _row[5]
        local fullframe = _row[6]
        local options = _row["options"]
        if not options then
            options = {}
        end

        -- Find the application's object, if wanted
        if _row[1] then
            if type(_row[1]) == "userdata" then
                app = _row[1]
            else
                app = application.get(_row[1])
                if not app then
                    print("Unable to find app: " .. _row[1])
                end
            end
        end

        -- Find the destination display, if wanted
        if _row[3] then
            if type(_row[3]) == "string" then
                local displays = fnutils.filter(screen.allScreens(), function(aScreen) return (aScreen:name() == _row[3]) or (aScreen:getUUID() == _row[3]) end)
                if displays then
                    -- TODO: This is bogus, multiple identical monitors will be impossible to lay out
                    display = displays[1]
                end
            elseif type(_row[3]) == "function" then
                display = _row[3]()
            elseif fnutils.contains(screen.allScreens(), _row[3]) then
                display = _row[3]
            else
                -- Default to the main screen if the passed-in screen isn't found; useful for
                -- layouts activated using the screen watcher, meaning that screens in layouts may
                -- not be in the current screen configuration.
                display = screen.primaryScreen()
            end
        else
            display = screen.primaryScreen()
        end

        if not display then
            print("Unable to find display: ", _row[3])
        else
            displaypoint = geometry.point(display:frame().x, display:frame().y)
        end

        -- Find the matching windows, if any
        if type(_row[2]) == "userdata" then
            wins = {_row[2]}
        elseif type(_row[2]) == "function" then
            if app then
                wins = _row[2](app:name())
            else
                wins = _row[2](nil)
            end
        elseif type(_row[2]) == "string" then
            if app then
                wins = fnutils.filter(app:allWindows(), function(win) return windowTitleComparator(win:title(), _row[2]) end)
            else
                wins = fnutils.filter(window:allWindows(), function(win) return windowTitleComparator(win:title(), _row[2]) end)
            end
        elseif app then
            wins = app:allWindows()
        end

        -- Apply the display/frame positions requested, if any
        if not wins then
            print(_row[1],_row[2])
            print("No windows matched, skipping.")
        else
            for _,_win in pairs(wins) do
                local winframe = nil
                local screenrect = nil

                -- Move window to destination display, if wanted
                if display and displaypoint and display ~= _win:screen() then
                    _win:setTopLeft(displaypoint)
                end

                -- Apply supplied position, if any
                if unit then
                    local realizedunit = unit
                    if type(realizedunit) == "function" then
                      realizedunit = realizedunit(_win)
                    end
                    _win:moveToUnit(realizedunit)
                elseif frame then
                    local realizedframe = frame
                    if type(realizedframe) == "function" then
                      realizedframe = realizedframe(_win)
                    end
                    winframe = realizedframe
                    screenrect = _win:screen():frame()
                elseif fullframe then
                    local realizedfullframe = fullframe
                    if type(realizedfullframe) == "function" then
                      realizedfullframe = realizedfullframe(_win)
                    end
                    winframe = realizedfullframe
                    screenrect = _win:screen():fullFrame()
                end

                if winframe then
                    if winframe.x < 0 or winframe.y < 0 then
                        if winframe.x < 0 and not options["absolute_x"] then
                            winframe.x = screenrect.w + winframe.x
                        end
                        if winframe.y < 0 and not options["absolute_y"] then
                            winframe.y = screenrect.h + winframe.y
                        end
                    end
                    _win:setFrame(winframe)
                end
            end
        end
    end
end

return layout
