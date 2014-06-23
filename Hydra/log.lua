api.log.lines = {}
api.log._buffer = ""
api.log.maxlines = 500

api.log.handlers = {}

function api.log.addhandler(fn)
  table.insert(api.log.handlers, fn)
  return #api.log.handlers
end

function api.log.removehandler(idx)
  api.log.handlers[idx] = nil
end

local function addline(str)
  table.insert(api.log.lines, str)

  if # api.log.lines == api.log.maxlines + 1 then
    -- we get called once per line; can't ever be maxlen + 2
    table.remove(api.log.lines, 1)
  end
end

api.log.addhandler(addline)
-- api.log.addhandler(function(str) api.alert("log: " .. str) end)

function api.log._gotline(str)
  api.log._buffer = api.log._buffer .. str:gsub("\r", "\n")

  while true do
    local startindex, endindex = string.find(api.log._buffer, "\n", 1, true)
    if not startindex then break end

    local newstr = string.sub(api.log._buffer, 1, startindex - 1)
    api.log._buffer = string.sub(api.log._buffer, endindex + 1, -1)

    -- call all the registered callbacks
    for _, fn in pairs(api.log.handlers) do
      fn(newstr)
    end
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

    local size = win:getsize()

    for linenum = pos, math.min(pos + size.h, # api.log.lines) do
      local line = api.log.lines[linenum]
      for i = 1, math.min(#line, size.w) do
        local c = line:sub(i,i)
        win:set(c:byte(), i, linenum - pos + 1, fg, bg)
      end
    end
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
        pos = math.max(pos, 1)
        pos = math.min(pos, # api.log.lines)
      end
      redraw()
  end)

  local loghandler = api.log.addhandler(redraw)

  win:closed(function()
      api.log.removehandler(loghandler)
  end)

  redraw()
  win:focus()

  return win
end
