local Stdin = {}
function Stdin.new()
  return setmetatable({pos = 1, chars = {}}, {__index = Stdin})
end

function Stdin:tostring()
  return table.concat(self.chars)
end

function Stdin:reset()
  self.chars = {}
  self.pos = 1
end

function Stdin:deletechar(dir)
  local delpos = self.pos
  if dir < 0 then delpos = delpos - 1 end
  if delpos < 1 or delpos > #self.chars then return end
  table.remove(self.chars, delpos)
  if dir < 0 then
    self.pos = self.pos - 1
  end
end

function Stdin:gochar(dir)
  if dir < 0 then
    self.pos = math.max(self.pos - 1, 1)
  else
    self.pos = math.min(self.pos + 1, #self.chars + 1)
  end
end

function Stdin:insertchar(char)
  table.insert(self.chars, self.pos, char)
  self.pos = self.pos + 1
end

doc.hydra.repl = {"hydra.repl() -> textgrid", "Opens a readline-like REPL (Read-Eval-Print-Loop) that has full access to Hydra's API; type 'help' for more info."}
function hydra.repl()
  local win = textgrid.open()
  win:settitle("Hydra REPL")
  win:protect()

  local fg = "00FF00"
  local bg = "222222"

  local scrollpos = 0

  local stdout = {}
  local stdin = Stdin.new()

  local function printline(win, line, gridwidth, y)
    if line == nil then return end
    local chars = utf8.chars(line)
    for x = 1, math.min(#chars, gridwidth) do
      win:setchar(chars[x], x, y)
    end
  end

  local function printscrollback()
    local size = win:getsize()
    for y = 1, math.min(#stdout, size.h) do
      printline(win, stdout[y + scrollpos], size.w, y)
    end

    local promptlocation = #stdout - scrollpos + 1
    if promptlocation <= size.h then
      printline(win, "> " .. stdin:tostring(), size.w, promptlocation)
      win:setcharfg(bg, 2 + stdin.pos, promptlocation)
      win:setcharbg(fg, 2 + stdin.pos, promptlocation)
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

  local loghandler = logger.addhandler(receivedlog)

  function win.closed()
    logger.removehandler(loghandler)
  end

  local function runcommand()
    local command = stdin:tostring()
    stdin:reset()

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
      runcommand()
      ensurecursorvisible()
    elseif t.key == "delete" or (t.key == 'h' and t.ctrl) then
      -- backspace
      stdin:deletechar(-1)
      ensurecursorvisible()
    elseif t.key == "d" and t.ctrl then
      stdin:deletechar(1)
      ensurecursorvisible()
    elseif t.key == 'p' and t.alt then
      scrollpos = scrollpos - 1
      restrictscrollpos()
    elseif t.key == 'n' and t.alt then
      scrollpos = scrollpos + 1
      restrictscrollpos()
    elseif t.key == 'left' then
      stdin:gochar(-1)
      ensurecursorvisible()
    elseif t.key == 'right' then
      stdin:gochar(1)
      ensurecursorvisible()
    else
      stdin:insertchar(t.key)
      ensurecursorvisible()
    end
    redraw()
  end

  redraw()
  win:focus()

  return win
end
