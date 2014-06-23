-- Save this as ~/.hydra/init.lua and choose Reload Config from the menu

api.alert("Hydra config loaded", 1.5)

api.menu.show(function()
    return {
      {title = "Reload Config", fn = api.reload},
      {title = "-"},
      {title = "About", fn = api.showabout},
      {title = "Quit Hydra", fn = os.exit},
    }
end)

api.hotkey.new({"cmd", "ctrl", "alt"}, "J", function()
    -- move the window to the right a bit, and make it a little shorter
    local win = api.window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end):enable()
