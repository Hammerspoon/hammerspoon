api.log = {}
doc.api.log = {__doc = "Functionality to assist with debugging and experimentation."}

api.log.rawprint = print
function print(...)
  api.log.rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  -- using table.concat here is safe, because we just stringified all the values
  local str = table.concat(vals, "\t") .. "\n"
  api.log._gotline(str)
end

doc.api.log.lines = {"api.log.lines = {}", "List of lines logged so far; caps at api.log.maxlines. You may clear it by setting it to {} yourself."}
api.log.lines = {}

api.log._buffer = ""

doc.api.log.maxlines = {"api.log.maxlines = 500", "Maximum number of lines to be logged."}
api.log.maxlines = 500

api.log.handlers = {}

doc.api.log.addhandler = {"api.log.addhandler(fn(str)) -> index", "Registers a function to handle new log lines."}
function api.log.addhandler(fn)
  table.insert(api.log.handlers, fn)
  return #api.log.handlers
end

doc.api.log.removehandler = {"api.log.removehandler(index)", "Unregisters a function that handles new log lines."}
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

doc.api.log.show = {"api.log.show() -> textgrid", "Opens a textgrid that can browse all logs."}
function api.log.show()
  local win = api.textgrid.open()
  win:protect()

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
        win:set(c, i, linenum - pos + 1, fg, bg)
      end
    end
  end

  win.resized = redraw

  function win.keydown(t)
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
  end

  local loghandler = api.log.addhandler(redraw)

  function win.closed()
    api.log.removehandler(loghandler)
  end

  redraw()
  win:focus()

  return win
end
