function hydra.app:visiblewindows()
  return hydra.fn.filter(self:allwindows(), hydra.window.isvisible)
end

function hydra.app.launchorfocus(name)
  os.execute("open -a " .. name)
end
