doc.textgrid.textgrids = {"textgrid.textgrids = {}", "All currently open textgrid windows; do not mutate this at all."}
textgrid.textgrids = {}
textgrid.textgrids.n = 0

doc.textgrid.open = {"textgrid.open() -> textgrid", "Opens a new textgrid window."}
function textgrid.open()
  local tg = textgrid._open()

  local id = textgrid.textgrids.n + 1
  tg.__id = id

  textgrid.textgrids[id] = tg
  textgrid.textgrids.n = id

  return tg
end

doc.textgrid.close = {"textgrid:close()", "Closes the given textgrid window."}
function textgrid:close()
  textgrid.textgrids[self.__id] = nil
  return self:_close()
end

doc.textgrid.protect = {"textgrid:protect()", "Prevents the textgrid from closing when your config is reloaded."}
function textgrid:protect()
  textgrid.textgrids[self.__id] = nil
  self.__id = nil
end

doc.textgrid.closeall = {"textgrid.closeall()", "Closes all non-protected textgrids; called automatically when user config is reloaded."}
function textgrid.closeall()
  for i, tg in pairs(textgrid.textgrids) do
    if tg and i ~= "n" then tg:close() end
  end
  textgrid.textgrids.n = 0
end

doc.textgrid.window = {"textgrid:window() -> window", "Return the window that represents the given textgrid."}
function textgrid:window()
  for _, win in window.allwindows() do
    if self:id() == win:id() then return win end
  end
  return nil
end
