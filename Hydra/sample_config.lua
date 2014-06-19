-- Save this as ~/.hydra/init.lua and choose Reload Config from the menu

local hotkey = require("hotkey")
local window = require("window")
local alert = require("alert")
local menu = require("menu")
local hydra = require("hydra")

alert.show("Hydra config loaded", 1.5)

menu.show(function()
    return {
      {title = "Reload Config", fn = hydra.reload},
      {title = "-"},
      {title = "About", fn = hydra.show_about_panel},
      {title = "Quit Hydra", fn = hydra.quit},
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
