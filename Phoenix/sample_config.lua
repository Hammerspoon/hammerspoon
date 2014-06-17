-- Save this as ~/.phoenix/init.lua and choose Reload Config from the menu

local hotkey = require("hotkey")
local window = require("window")
local alert = require("alert")
local menu = require("menu")
local phoenix = require("phoenix")

alert.show("Phoenix config loaded", 1.5)

menu.show(function()
    return {
      {title = "Reload Config", fn = phoenix.reload},
      {title = "-"},
      {title = "About", fn = phoenix.show_about_panel},
      {title = "Quit Phoenix", fn = phoenix.quit},
    }
end)

hotkey.bind({"cmd", "ctrl", "alt"}, "J", function()
    -- move the window to the right a bit, and make it a little shorter
    local win = window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end)
