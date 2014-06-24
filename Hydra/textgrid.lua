api.doc.textgrid.textgrids = {"api.textgrid.textgrids = {}", "All currently open textgrid windows; do not mutate this at all."}
api.textgrid.textgrids = {}

api.doc.textgrid.open = {"api.textgrid.open() -> textgrid", "Opens a new textgrid window."}
function api.textgrid.open()
  local tg = api.textgrid._open()
  table.insert(api.textgrid.textgrids, tg)
  tg.__pos = # api.textgrid.textgrids
  return tg
end

api.doc.textgrid.close = {"api.textgrid:close()", "Closes the given textgrid window."}
function api.textgrid:close()
  table.remove(api.textgrid.textgrids, self.__pos)
  return self:_close()
end

api.doc.textgrid.livelong = {"api.textgrid:livelong()", "Prevents the textgrid from closing when your config is reloaded."}
function api.textgrid:livelong()
  table.remove(api.textgrid.textgrids, self.__pos)
  self.__pos = nil
end

function api.textgrid._clear()
  for i = # api.textgrid.textgrids, 1, -1 do
    local tg = api.textgrid.textgrids[i]
    tg:close()
  end
end
