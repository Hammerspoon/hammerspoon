logger = {}
--- === logger ===
---
--- Functionality to assist with debugging and experimentation.

logger.rawprint = print
function print(...)
  logger.rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  -- using table.concat here is safe, because we just stringified all the values
  local str = table.concat(vals, "\t") .. "\n"
  logger._gotline(str)
end

--- logger.lines = {}
--- List of lines logged so far; caps at logger.maxlines. You may clear it by setting it to {} yourself.
logger.lines = {}

logger._buffer = ""

--- logger.maxlines = 500
--- Maximum number of lines to be logged.
logger.maxlines = 500

logger.handlers = {}

--- logger.addhandler(fn(str)) -> index
--- Registers a function to handle new log lines.
function logger.addhandler(fn)
  table.insert(logger.handlers, fn)
  return #logger.handlers
end

--- logger.removehandler(index)
--- Unregisters a function that handles new log lines.
function logger.removehandler(idx)
  logger.handlers[idx] = nil
end

local function addline(str)
  table.insert(logger.lines, str)

  if # logger.lines == logger.maxlines + 1 then
    -- we get called once per line; can't ever be maxlen + 2
    table.remove(logger.lines, 1)
  end
end

logger.addhandler(addline)
-- logger.addhandler(function(str) hydra.alert("log: " .. str) end)

function logger._gotline(str)
  logger._buffer = logger._buffer .. str:gsub("\r", "\n")

  while true do
    local startindex, endindex = string.find(logger._buffer, "\n", 1, true)
    if not startindex then break end

    local newstr = string.sub(logger._buffer, 1, startindex - 1)
    logger._buffer = string.sub(logger._buffer, endindex + 1, -1)

    -- call all the registered callbacks
    for _, fn in pairs(logger.handlers) do
      fn(newstr)
    end
  end
end

--- logger.show() -> textgrid
--- Opens a textgrid that can browse all logs.
function logger.show()
  local win = textgrid.create()
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

    for linenum = pos, math.min(pos + size.h, # logger.lines) do
      local line = logger.lines[linenum]
      for i = 1, math.min(#line, size.w) do
        local c = line:sub(i,i)
        win:setchar(c, i, linenum - pos + 1)
      end
    end
  end

  win:resized(redraw)

  local function handlekey(t)
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
      pos = math.min(pos, # logger.lines)
    end
    redraw()
  end

  win:keydown(handlekey)

  local loghandler = logger.addhandler(redraw)
  local removeloghandler = function() logger.removehandler(loghandler) end
  win:hidden(removeloghandler)

  redraw()
  win:focus()

  return win
end
