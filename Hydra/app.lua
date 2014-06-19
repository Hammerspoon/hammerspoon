function hydra.app:visiblewindows()
  return hydra.fn.filter(self:allwindows(), hydra.window.isvisible)
end
