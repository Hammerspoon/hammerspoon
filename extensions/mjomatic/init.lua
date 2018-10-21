--- === hs.mjomatic ===
---
--- tmuxomatic-like window management

local mjomatic = {}

local alert = require 'hs.alert'
local application = require 'hs.application'
local screen = require 'hs.screen'

local gridh
local gridw

local function resizetogrid(window, coords)
    -- alert.show(string.format('move window %q to %d,%d-%d,%d', window:title(), coords.r1, coords.c1, coords.r2, coords.c2), 20)

    -- collect screen dimensions
    local frame = screen.mainScreen():fullFrame()
    local framew = screen.mainScreen():frame()

    local h = framew.h
    local w = frame.w
    local x = framew.x
    local y = framew.y
    -- alert.show(string.format('screen dimensions %d,%d at %d,%d', h, w, x, y))
    local hdelta = h / gridh
    local wdelta = w / gridw

    -- alert.show('hdelta='..hdelta, 5)
    -- alert.show('wdelta='..wdelta, 5)
    local newframe = {}
    newframe.x = (coords.c1-1) * wdelta + x
    newframe.y = (coords.r1-1) * hdelta + y
    newframe.h = (coords.r2-coords.r1+1) * hdelta
    newframe.w = (coords.c2-coords.c1+1) * wdelta
    window:setFrame(newframe)
    -- alert.show(string.format('new frame for %q is %d*%d at %d,%d', window:title(), newframe.w, newframe.h, newframe.x, newframe.y), 20)
end

--- hs.mjomatic.go(cfg)
--- Function
--- Applies a configuration to the currently open windows
---
--- Parameters:
---  * cfg - A table containing a series of strings, representing the desired window layout
---
--- Returns:
---  * None
---
--- Notes:
---  * An example use:
---
--- ~~~lua
--- mjomatic.go({
--- "CCCCCCCCCCCCCiiiiiiiiiii      # <-- The windowgram, it defines the shapes and positions of windows",
--- "CCCCCCCCCCCCCiiiiiiiiiii",
--- "SSSSSSSSSSSSSiiiiiiiiiii",
--- "SSSSSSSSSSSSSYYYYYYYYYYY",
--- "SSSSSSSSSSSSSYYYYYYYYYYY",
--- "",
--- "C Google Chrome            # <-- window C has application():title() 'Google Chrome'",
--- "i iTerm",
--- "Y YoruFukurou",
--- "S Sublime Text 2"})
--- ~~~

function mjomatic.go(cfg)
    -- alert.show('mjomatic is go')
    local grid = {}
    local map = {}

    local target = grid


    -- FIXME move gsub stuff to separate function (iterator wrapper around io.lines?)
    --       then do parsing in two loops so we don't need to muck about with target
    --       and do some parsing inline
    for _,l in ipairs(cfg) do
        l = l:gsub('#.*','')        -- strip comments
        l = l:gsub('%s*$','')       -- strip trailing whitespace
        -- alert.show(l)
        if l:len() == 0 then
            if #grid > 0 then
                if target == grid then
                    target = map
                elseif #map > 0 then
                    error('config has more than two chunks')
                end
            end
        else
            table.insert(target, l)
        end
    end

    -- alert.show('grid size '..#grid)
    -- alert.show('map size '..#map)

    gridh = #grid
    gridw = nil

    local windows = {}
    local titlemap = {}

    for _, v in ipairs(map) do
        local key = v:sub(1,1)
        local title = v:sub(3)
        -- alert.show(string.format('%s=%s', key, title))
        titlemap[title] = key
    end

    for row, v in ipairs(grid) do
        if gridw then
            if gridw ~= v:len() then
                error('inconsistent grid width')
            end
        else
            gridw=v:len()
        end

        for column = 1, #v do
            local char = v:sub(column, column)
            if not windows[char] then
                -- new window, create it with size 1x1
                windows[char] = {r1=row, c1=column, r2=row, c2=column}
            else
                -- expand it
                windows[char].r2=row
                windows[char].c2=column
            end
        end
    end

    -- alert.show('grid h='..gridh..' w='..gridw)
    -- alert.show('windows:')
    --for char, window in pairs(windows) do
        -- alert.show(string.format('window %s: top left %d,%d bottom right %d,%d', char, window.r1, window.c1, window.r2, window.c2))
    --end

    for title, key in pairs(titlemap) do
        -- alert.show(string.format("title %s key %s", title, key))
        if not windows[key] then
            error(string.format('no window found for application %s (%s)', title, key))
        end
        local app = application.get(title)
        local window = app and app:mainWindow()
        -- alert.show(string.format('application title for %q is %q, main window %q', title, app:title(), window:title()))
        if window then
            resizetogrid(window, windows[key])
        else
            alert.show(string.format('application %s has no main window', app:title()))
        end
    end
end

return mjomatic
