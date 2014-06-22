api.textgrid.textgrids = {}

function api.textgrid.open()
  local tg = api.textgrid._open()
  table.insert(api.textgrid.textgrids, tg)
  tg.__pos = # api.textgrid.textgrids
  return tg
end

function api.textgrid:close()
  table.remove(api.textgrid.textgrids, self.__pos)
  return self:_close()
end

function api.textgrid:livelong()
  table.remove(api.textgrid.textgrids, self.__pos)
  self.__pos = nil
end
