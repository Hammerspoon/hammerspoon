--- application:visiblewindows() -> win[]
--- Returns only the app's windows that are visible.
function application:visiblewindows()
  return fnutils.filter(self:allwindows(), window.isvisible)
end

--- application.launchorfocus(name)
--- Launches the app with the given name, or activates it if it's already running.
function application.launchorfocus(name)
  os.execute("open -a \"" .. name .. "\"")
end
