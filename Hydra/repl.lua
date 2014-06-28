api.repl = {}

doc.api.repl = {__doc = "Read-Eval-Print-Loop"}

doc.api.repl.open = {"api.repl.open() -> textgrid", "Opens a (primitive) REPL that has full access to Hydra's API"}
function api.repl.open()
  local win = api.textgrid.open()
  win:settitle("Hydra REPL")
  win:protect()

  local fg = "00FF00"
  local bg = "222222"

  local scrollpos = 0
  local cursorpos = 1

  local stdout = {}
  local stdin = ""

  local function derivepagetable()
    local t = {}
    for i, v in ipairs(stdout) do
      t[i] = v
    end
    table.insert(t, "> " .. stdin)
    return t
  end

  local function printscrollback()
    local size = win:getsize()
    local pagetable = derivepagetable()

    for i = 1, math.min(#pagetable, size.h) do
      local line = pagetable[i + scrollpos]
      if line then
        local chars = api.utf8.chars(line)
        for x = 1, math.min(#chars, size.w) do
          win:set(chars[x], x, i, fg, bg)
        end
      end
    end
  end

  local function restrictscrollpos()
    scrollpos = math.max(scrollpos, 0)
    scrollpos = math.min(scrollpos, #stdout)
  end

  -- local function printcursor(x, y)
  --   win:set(" ", x, y, bg, fg)
  -- end

  local function redraw()
    win:clear(bg)
    printscrollback()
  end

  local function ensurecursorvisible()
    local size = win:getsize()
    scrollpos = math.max(scrollpos, (#stdout+1) - size.h)
  end

  win.resized = redraw

  local function receivedlog(str)
    table.insert(stdout, str)
    redraw()
  end

  local loghandler = api.log.addhandler(receivedlog)

  function win.closed()
    api.log.removehandler(loghandler)
  end

  local function runcommand()
    local command = stdin
    stdin = ""

    table.insert(stdout, "> " .. command)

    local fn = load(command)
    local success, result = pcall(fn)
    result = tostring(result)
    if not success then result = "error: " .. result end

    -- add each line separately
    for s in string.gmatch(result, "[^\n]+") do
      table.insert(stdout, s)
    end
  end

  function win.keydown(t)
    if t.key == "return" then runcommand(); ensurecursorvisible()
    elseif t.key == "delete" --[[i.e. backspace]] then stdin = stdin:sub(0, -2); ensurecursorvisible()
    elseif t.key == 'p' and t.alt then scrollpos = scrollpos - 1; restrictscrollpos()
    elseif t.key == 'n' and t.alt then scrollpos = scrollpos + 1; restrictscrollpos()
    else stdin = stdin .. t.key; ensurecursorvisible()
    end
    redraw()
  end

  redraw()
  win:focus()

  return win
end
