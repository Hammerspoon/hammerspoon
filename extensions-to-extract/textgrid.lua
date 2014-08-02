textgrid.textgrids = {}

--- textgrid.create() -> textgrid
--- Creates a new (hidden) textgrid window.
function textgrid.create()
  local tg = textgrid._create()
  textgrid.textgrids[tg:id()] = tg
  return tg
end

--- textgrid:destroy()
--- Destroy the given textgrid window; after calling this, it can no longer be used; to temporarily hide it, use textgrid:hide() instead.
function textgrid:destroy()
  self:hide()
  textgrid.textgrids[self:id()] = nil
end

--- textgrid:protect()
--- Prevents the textgrid from being destroyed when your config is reloaded.
function textgrid:protect()
  textgrid.textgrids[self:id()] = nil
end

--- textgrid.destroyall()
--- Destroys all non-protected textgrids; called automatically when user config is reloaded.
function textgrid.destroyall()
  for _, tg in pairs(textgrid.textgrids) do
    tg:destroy()
  end
end

--- textgrid:window() -> window
--- Return a window (i.e. of the `window` module) that represents the given textgrid.
function textgrid:window()
  return fnutils.find(window.allwindows(), function(win) return win:id() == self:id() end)
end
