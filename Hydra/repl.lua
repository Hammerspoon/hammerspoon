api.repl = {}

doc.api.repl = {__doc = "Read-Eval-Print-Loop"}

doc.api.repl.open = {"api.repl.open() -> textgrid", "Opens a readline-like REPL that has full access to Hydra's API"}
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
          win:setchar(chars[x], x, i)
        end

        if i + scrollpos == #pagetable then
          -- we're at the cursor line
          local c
          if cursorpos > #stdin then c = ' ' else c = stdin:sub(cursorpos,cursorpos) end
          win:setchar(c, 2 + cursorpos, i)
          win:setcharfg(bg, 2 + cursorpos, i)
          win:setcharbg(fg, 2 + cursorpos, i)
        end
      end
    end
  end

  local function restrictscrollpos()
    scrollpos = math.max(scrollpos, 0)
    scrollpos = math.min(scrollpos, #stdout)
  end

  local function redraw()
    win:setbg(bg)
    win:setfg(fg)
    win:clear()
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

    local results = table.pack(pcall(load("return " .. command)))
    if not results[1] then
      results = table.pack(pcall(load(command)))
    end

    local success = results[1]
    table.remove(results, 1)

    local resultstr
    if success then
      for i = 1, results.n - 1 do results[i] = tostring(results[i]) end
      resultstr = table.concat(results, ", ")
    else
      resultstr = "error: " .. results[2]
    end

    -- add each line separately
    for s in string.gmatch(resultstr, "[^\n]+") do
      table.insert(stdout, s)
    end
  end

  function win.keydown(t)
    if t.key == "return" then
      cursorpos = 1
      runcommand()
      ensurecursorvisible()
    elseif t.key == "delete" --[[i.e. backspace]] then
      stdin = stdin:sub(0, -2)
      cursorpos = math.max(cursorpos - 1, 1)
      ensurecursorvisible()
    elseif t.key == 'p' and t.alt then
      scrollpos = scrollpos - 1
      restrictscrollpos()
    elseif t.key == 'n' and t.alt then
      scrollpos = scrollpos + 1
      restrictscrollpos()
    elseif t.key == 'left' then
      cursorpos = math.max(cursorpos - 1, 1)
      ensurecursorvisible()
    elseif t.key == 'right' then
      cursorpos = math.min(cursorpos + 1, #stdin+1)
      ensurecursorvisible()
    else
      cursorpos = cursorpos + 1
      stdin = stdin .. t.key
      ensurecursorvisible()
    end
    redraw()
  end

  redraw()
  win:focus()

  return win
end
