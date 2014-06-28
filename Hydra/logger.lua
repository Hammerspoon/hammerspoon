api.logger = {}
doc.api.logger = {__doc = "Functionality to assist with debugging and experimentation."}

api.logger.rawprint = print
function print(...)
  api.logger.rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  -- using table.concat here is safe, because we just stringified all the values
  local str = table.concat(vals, "\t") .. "\n"
  api.logger._gotline(str)
end

doc.api.logger.lines = {"api.logger.lines = {}", "List of lines logged so far; caps at api.logger.maxlines. You may clear it by setting it to {} yourself."}
api.logger.lines = {}

api.logger._buffer = ""

doc.api.logger.maxlines = {"api.logger.maxlines = 500", "Maximum number of lines to be logged."}
api.logger.maxlines = 500

api.logger.handlers = {}

doc.api.logger.addhandler = {"api.logger.addhandler(fn(str)) -> index", "Registers a function to handle new log lines."}
function api.logger.addhandler(fn)
  table.insert(api.logger.handlers, fn)
  return #api.logger.handlers
end

doc.api.logger.removehandler = {"api.logger.removehandler(index)", "Unregisters a function that handles new log lines."}
function api.logger.removehandler(idx)
  api.logger.handlers[idx] = nil
end

local function addline(str)
  table.insert(api.logger.lines, str)

  if # api.logger.lines == api.logger.maxlines + 1 then
    -- we get called once per line; can't ever be maxlen + 2
    table.remove(api.logger.lines, 1)
  end
end

api.logger.addhandler(addline)
-- api.logger.addhandler(function(str) api.alert("log: " .. str) end)

function api.logger._gotline(str)
  api.logger._buffer = api.logger._buffer .. str:gsub("\r", "\n")

  while true do
    local startindex, endindex = string.find(api.logger._buffer, "\n", 1, true)
    if not startindex then break end

    local newstr = string.sub(api.logger._buffer, 1, startindex - 1)
    api.logger._buffer = string.sub(api.logger._buffer, endindex + 1, -1)

    -- call all the registered callbacks
    for _, fn in pairs(api.logger.handlers) do
      fn(newstr)
    end
  end
end

doc.api.logger.show = {"api.logger.show() -> textgrid", "Opens a textgrid that can browse all logs."}
function api.logger.show()
  local win = api.textgrid.open()
  win:protect()

  local pos = 1 -- i.e. line currently at top of log textgrid

  local fg = "00FF00"
  local bg = "222222"

  win:settitle("Hydra Logs")

  local function redraw()
    win:setbg(bg)
    win:setfg(fg)
    win:clear()

    local size = win:getsize()

    for linenum = pos, math.min(pos + size.h, # api.logger.lines) do
      local line = api.logger.lines[linenum]
      for i = 1, math.min(#line, size.w) do
        local c = line:sub(i,i)
        win:setchar(c, i, linenum - pos + 1)
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
      pos = math.min(pos, # api.logger.lines)
    end
    redraw()
  end

  local loghandler = api.logger.addhandler(redraw)

  function win.closed()
    api.logger.removehandler(loghandler)
  end

  redraw()
  win:focus()

  return win
end
