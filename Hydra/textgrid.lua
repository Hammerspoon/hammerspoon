textgrid.textgrids = {}

doc.textgrid.create = {"textgrid.create() -> textgrid", "Creates a new (hidden) textgrid window."}
function textgrid.create()
  local tg = textgrid._create()
  textgrid.textgrids[tg:id()] = tg
  return tg
end

doc.textgrid.close = {"textgrid:close()", "Closes the given textgrid window; after calling this, it can no longer be used; to temporarily close it, use textgrid:hide() instead."}
function textgrid:close()
  textgrid.textgrids[self:id()] = nil
  return self:_close()
end

doc.textgrid.protect = {"textgrid:protect()", "Prevents the textgrid from being closed when your config is reloaded."}
function textgrid:protect()
  textgrid.textgrids[self:id()] = nil
end

doc.textgrid.closeall = {"textgrid.closeall()", "Closes all non-protected textgrids; called automatically when user config is reloaded."}
function textgrid.closeall()
  for _, tg in pairs(textgrid.textgrids) do
    tg:close()
  end
end

doc.textgrid.window = {"textgrid:window() -> window", "Return the window that represents the given textgrid."}
function textgrid:window()
  return fnutils.find(window.allwindows(), function(win) return win:id() == self:id() end)
end
