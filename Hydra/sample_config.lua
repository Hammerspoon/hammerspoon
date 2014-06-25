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
  os.execute('open https://github.com/sdegutis/Hydra/releases')
end

-- what to do when an udpate is checked
function api.updates.available(available)
  if available then
    api.notify.show("Hydra update available", "", "Click here to see the changelog and maybe even install it", "showupdate")
  else
    api.alert("No update available.")
  end
end

-- Uncomment this if you want Hydra to make sure it launches at login
-- api.autolaunch.set(true)

-- check for updates every week
api.timer.new(api.timer.weeks(1), api.updates.check):start()
api.notify.register("showupdate", showupdate)

-- also check right away
api.updates.check()
