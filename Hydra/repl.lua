api.repl = {}

doc.api.repl = {__doc = "Read-Eval-Print-Loop"}

doc.api.repl.open = {"api.repl.open() -> textgrid", "Opens a (primitive) REPL that has full access to Hydra's API"}
function api.repl.open()
  local win = api.textgrid.open()
  win:protect()

  local fg = "00FF00"
  local bg = "222222"

  win:settitle("Hydra REPL")

  local stdout = ""
  local stdin = ""

  local function printstr(x, y, str)
    local size = win:getsize()
    local w = size.w
    local h = size.h

    for i = 1, #str do
      if x == w + 1 then
        x = 1
        y = y + 1
      end

      if y == h + 1 then break end

      local c = str:sub(i,i):byte()
      if c == string.byte("\n") then
        x = 1
        y = y + 1
      else
        win:set(c, x, y, fg, bg)
        x = x + 1
      end
    end
  end

  local function clearbottom()
    local size = win:getsize()
    local w = size.w
    local h = size.h

    for x = 1, w do
      win:set(string.byte(" "), x, h, fg, bg)
    end
  end

  local function printcursor(x, y)
    win:set(string.byte(" "), x, y, bg, fg)
  end

  local function redraw()
    local size = win:getsize()
    local w = size.w
    local h = size.h

    win:clear(bg)
    printstr(1, 1, stdout)
    clearbottom()
    printstr(1, h, "> " .. stdin)
    printcursor(3 + string.len(stdin), h)
  end

  win.resized = redraw

  local function receivedlog(str)
    stdout = stdout .. str .. "\n"
    redraw()
  end

  local loghandler = api.log.addhandler(receivedlog)

  function win.closed()
    api.log.removehandler(loghandler)
  end

  function win.keydown(t)
    if t.key == "return" then
      local command = stdin
      stdin = ""

      stdout = stdout .. "> " .. command .. "\n"

      local fn = load(command)
      local success, result = pcall(fn)
      result = tostring(result)
      if not success then result = "error: " .. result end

      stdout = stdout .. result .. "\n"
    elseif t.key == "delete" then -- i.e. backspace
      stdin = stdin:sub(0, -2)
    else
      stdin = stdin .. t.key
    end
    redraw()
  end

  redraw()
  win:focus()

  return win
end
