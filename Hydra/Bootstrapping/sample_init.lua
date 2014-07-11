-- Hi!
-- Save this as ~/.hydra/init.lua and choose Reload Config from the menu

hydra.alert("Hydra sample config loaded", 1.5)

-- open a repl
--   the repl is a Lua prompt; type "print('hello world')"
--   when you're in the repl, type "help" to get started
--   almost all readline functionality works in the repl
hotkey.bind({"cmd", "ctrl", "alt"}, "R", repl.open)

-- save the time when updates are checked
function checkforupdates()
  updates.check()
  settings.set('lastcheckedupdates', os.time())
end

-- show a helpful menu
menu.show(function()
    local updatetitles = {[true] = "Install Update", [false] = "Check for Update..."}
    local updatefns = {[true] = updates.install, [false] = checkforupdates}
    local hasupdate = (updates.newversion ~= nil)

    return {
      {title = "Reload Config", fn = hydra.reload},
      {title = "Open REPL", fn = repl.open},
      {title = "-"},
      {title = "About", fn = hydra.showabout},
      {title = updatetitles[hasupdate], fn = updatefns[hasupdate]},
      {title = "Quit Hydra", fn = os.exit},
    }
end)

-- move the window to the right half of the screen
function movewindow_righthalf()
  local win = window.focusedwindow()
  local newframe = win:screen():frame_without_dock_or_menu()
  newframe.w = newframe.w / 2
  newframe.x = newframe.w -- comment this line to push it to left half of screen
  win:setframe(newframe)
end

hotkey.new({"cmd", "ctrl", "alt"}, "L", movewindow_righthalf):enable()

-- show available updates
local function showupdate()
  os.execute('open https://github.com/sdegutis/Hydra/releases')
end

-- what to do when an update is checked
function updates.available(available)
  if available then
    notify.show("Hydra update available", "", "Click here to see the changelog and maybe even install it", "showupdate")
  else
    hydra.alert("No update available.")
  end
end

-- Uncomment this if you want Hydra to make sure it launches at login
-- autolaunch.set(true)

-- check for updates every week
timer.new(timer.weeks(1), checkforupdates):start()
notify.register("showupdate", showupdate)

-- if this is your first time running Hydra, you're launching it more than a week later, check now
local lastcheckedupdates = settings.get('lastcheckedupdates')
if lastcheckedupdates == nil or lastcheckedupdates <= os.time() - timer.days(7) then
  checkforupdates()
end




-- I've worked hard to make Hydra useful and easy to use. I've also
-- released it with a liberal open source license, so that you can do
-- with it as you please. So, instead of charging for licenses, I'm
-- asking for donations. If you find it helpful, I encourage you to
-- donate what you believe would have been a fair price for a license:

local function donate()
  os.execute("open 'https://www.paypal.com/cgi-bin/webscr?business=sbdegutis@gmail.com&cmd=_donations&item_name=Hydra.app%20donation'")
end

hotkey.bind({"cmd", "alt", "ctrl"}, "D", donate)
