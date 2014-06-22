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

function api.log.show()
  local win = api.textgrid.open()
  win:livelong()

  local pos = 1 -- i.e. line currently at top of log textgrid

  local fg = "00FF00"
  local bg = "222222"

  win:settitle("Hydra Logs")

  local function redraw()
    win:clear(bg)
    -- TODO: draw api.log.lines in textgrid, starting with line `pos`
  end

  win:resized(redraw)

  win:keydown(function(t)
      local size = win:getsize()
      local h = size.h

      -- this can't be cached on account of the textgrid's height could change
      local keytable = {
        j = 1,
        k = -1,
        n = (h-1),
        p = -(h-1),
        -- TODO: add emacs keys too
      }

      local scrollby = keytable[t.key]
      if scrollby then
        pos = pos + scrollby
        pos = math.min(pos, 1)
        pos = math.max(pos, # api.log.lines)
      end
      redraw()
  end)

  redraw()
  win:focus()

  return win
end
