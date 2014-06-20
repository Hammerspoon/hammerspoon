function api.app:visiblewindows()
  return api.fn.filter(self:allwindows(), api.window.isvisible)
end

function api.app.launchorfocus(name)
  os.execute("open -a " .. name)
end
