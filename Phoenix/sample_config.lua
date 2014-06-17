-- Save this as ~/.phoenix/init.lua and choose Reload Config from the menu

local hotkey = require("hotkey")
local window = require("window")
local alert = require("alert")

alert.show("Phoenix config loaded", 1.5)

hotkey.bind({"cmd", "ctrl", "alt"}, "J", function()
    -- move the window to the right a bit, and make it a little shorter
    local win = window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end)
