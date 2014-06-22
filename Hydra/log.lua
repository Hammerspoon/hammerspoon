api.log.lines = {}
api.log._buffer = ""
api.log.maxlines = 500

function api.log.gotline(str)
  table.insert(api.log.lines, str)

  if # api.log.lines == api.log.maxlines + 1 then
    -- we get called once per line; can't ever be maxlen + 2
    table.remove(api.log.lines, 1)
  end

  api.alert("log: " .. str)
end

function api.log._gotline(str)
  api.log._buffer = api.log._buffer .. str:gsub("\r", "\n")

  while true do
    local startindex, endindex = string.find(api.log._buffer, "\n", 1, true)
    if not startindex then break end

    local newstr = string.sub(api.log._buffer, 1, startindex - 1)
    api.log._buffer = string.sub(api.log._buffer, endindex + 1, -1)
    api.log.gotline(newstr)
  end
end
