api.alert("Hydra config loaded", 1.5)

-- show a helpful menu
api.menu.show(function()
    local updatetitles = {[true] = "Install Update", [false] = "Check for Update..."}
    local updatefns = {[true] = api.updates.install, [false] = api.updates.check}
    local hasupdate = (api.updates.newversion ~= nil)

    return {
      {title = "Reload Config", fn = api.reload},
      {title = "-"},
      {title = "About", fn = api.showabout},
      {title = updatetitles[hasupdate], fn = updatefns[hasupdate]},
      {title = "Quit Hydra", fn = os.exit},
    }
end)

-- move the window to the right a bit, and make it a little shorter
api.hotkey.new({"cmd", "ctrl", "alt"}, "J", function()
    local win = api.window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end):enable()

-- open a repl
api.hotkey.bind({"cmd", "ctrl", "alt"}, "R", api.repl.open)

-- show available updates
local function showupdate()
  local str = ""
  str = str .. "New version available: " .. api.updates.newversion .. "\n"
  str = str .. "Your version: " .. api.updates.currentversion .. "\n"
  str = str .. "You can install it via the Hydra menu bar icon\n"
  str = str .. "Changelog: " .. api.updates.changelog .. "\n"
  api.alert(str)
end

-- check for updates every week
api.timer.new(api.timer.weeks(1), api.updates.check):start()
api.notify.register("showupdate", showupdate)
