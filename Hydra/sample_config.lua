-- Save this as ~/.hydra/init.lua and choose Reload Config from the menu

hydra.alert("Hydra config loaded", 1.5)

hydra.menu.show(function()
    return {
      {title = "Reload Config", fn = hydra.reload},
      {title = "-"},
      {title = "About", fn = hydra.showabout},
      {title = "Quit Hydra", fn = os.exit},
    }
end)

hydra.hotkey({"cmd", "ctrl", "alt"}, "J", function()
    -- move the window to the right a bit, and make it a little shorter
    local win = hydra.window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end):enable()
