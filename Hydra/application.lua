doc.api.application.visiblewindows = {"api.application:visiblewindows() -> win[]", "Returns only the app's windows that are visible."}
function api.application:visiblewindows()
  return api.fnutils.filter(self:allwindows(), api.window.isvisible)
end

doc.api.application.launchorfocus = {"api.application.launchorfocus(name)", "Launches the app with the given name, or activates it if it's already running."}
function api.application.launchorfocus(name)
  os.execute("open -a " .. name)
end
