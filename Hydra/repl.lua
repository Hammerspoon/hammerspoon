local Stdin = {}
function Stdin.new()
  return setmetatable({pos = 1, chars = {}, cmds = {}, cmdpos = 1}, {__index = Stdin})
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

function Stdin:goline(dir)
  if dir < 0 then
    self.pos = 1
  else
    self.pos = #self.chars + 1
  end
end

function Stdin:killtoend()
  for i = self.pos, #self.chars do
    self.chars[i] = nil
  end
end

function Stdin:insertchar(char)
  table.insert(self.chars, self.pos, char)
  self.pos = self.pos + 1
end

function Stdin:addcommand(cmd)
  self.partialcmd = nil -- redundant?
  table.insert(self.cmds, cmd)
  self.cmdpos = #self.cmds + 1
end

function Stdin:maybesavecommand()
  if self.cmdpos == #self.cmds + 1 then
    self.partialcmd = self:tostring()
  end
end

function Stdin:usecurrenthistory()
  local partialcmd
  if self.cmdpos == #self.cmds + 1 then
    partialcmd = self.partialcmd
  else
    partialcmd = self.cmds[self.cmdpos]
  end

  self.chars = {}
  for i = 1, partialcmd:len() do
    local c = partialcmd:sub(i,i)
    table.insert(self.chars, c)
  end

  self.pos = #partialcmd + 1
end

function Stdin:historynext()
  self.cmdpos = math.min(self.cmdpos + 1, #self.cmds + 1)
  self:usecurrenthistory()
end

function Stdin:historyprev()
  self:maybesavecommand()
  self.cmdpos = math.max(self.cmdpos - 1, 1)
  self:usecurrenthistory()
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
    stdin:addcommand(command)

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

  local function runprompt()
    runcommand()
    ensurecursorvisible()
  end

  local function delcharbackward()
    stdin:deletechar(-1)
    ensurecursorvisible()
  end

  local function delcharforward()
    stdin:deletechar(1)
    ensurecursorvisible()
  end

  local function scrollcharup()
    scrollpos = scrollpos - 1
    restrictscrollpos()
  end

  local function scrollchardown()
    scrollpos = scrollpos + 1
    restrictscrollpos()
  end

  local function gocharforward()
    stdin:gochar(1)
    ensurecursorvisible()
  end

  local function gocharbackward()
    stdin:gochar(-1)
    ensurecursorvisible()
  end

  local function golinefirst()
    stdin:goline(-1)
    ensurecursorvisible()
  end

  local function golinelast()
    stdin:goline(1)
    ensurecursorvisible()
  end

  local function killtoend(t)
    stdin:killtoend()
    ensurecursorvisible()
  end

  local function insertchar(t)
    stdin:insertchar(t.key)
    ensurecursorvisible()
  end

  local function historynext()
    stdin:historynext()
    ensurecursorvisible()
  end

  local function historyprev()
    stdin:historyprev()
    ensurecursorvisible()
  end

  local mods = {
    none  = 0,
    ctrl  = 1,
    alt   = 2,
    cmd   = 4,
    shift = 8,
  }

  local keytable = {
    {"return", mods.none, runprompt},
    {"delete", mods.none, delcharbackward},

    {"h", mods.ctrl, delcharbackward},
    {"d", mods.ctrl, delcharforward},

    {"p", mods.alt, scrollcharup},
    {"n", mods.alt, scrollchardown},

    {"p", mods.ctrl, historyprev},
    {"n", mods.ctrl, historynext},

    {"b", mods.ctrl, gocharbackward},
    {"f", mods.ctrl, gocharforward},

    {"a", mods.ctrl, golinefirst},
    {"e", mods.ctrl, golinelast},

    {"k", mods.ctrl, killtoend},

    {"left",  mods.none, gocharbackward},
    {"right", mods.none, gocharforward},
  }

  function win.keydown(t)
    local mod = mods.none
    if t.ctrl  then mod = bit32.bor(mod, mods.ctrl) end
    if t.alt   then mod = bit32.bor(mod, mods.alt) end
    if t.cmd   then mod = bit32.bor(mod, mods.cmd) end
    if t.shift then mod = bit32.bor(mod, mods.shift) end

    local fn
    for _, maybe in pairs(keytable) do
      if t.key == maybe[1] and mod == maybe[2] then
        fn = maybe[3]
        break
      end
    end

    if fn == nil and mod == mods.none or mod == mods.shift then
      fn = insertchar
    end

    if fn then
      fn(t)
    end

    redraw()
  end

  redraw()
  win:focus()

  return win
end
