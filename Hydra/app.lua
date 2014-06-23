api.doc.app.visiblewindows = {"api.app:visiblewindows() -> win[]", "Returns only the app's windows that are visible."}
function api.app:visiblewindows()
  return api.fn.filter(self:allwindows(), api.window.isvisible)
end

api.doc.app.launchorfocus = {"api.app.launchorfocus(name)", "Launches the app with the given name, or activates it if it's already running."}
function api.app.launchorfocus(name)
  os.execute("open -a " .. name)
end
