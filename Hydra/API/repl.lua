--- repl
---
--- The REPL (Read-Eval-Print-Loop) is excellent for exploring and experiment with Hydra's API.
---
--- It has most of the familiar readline-like keybindings, including C-b, C-f, M-b, M-f to navigate your text, C-p and C-n to browse command history, etc.
---
--- Type `help` in the REPL for info on how to use the documentation system.


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

local function nextwordpos(str, pos)
  local _, _, pos = str:find("[%w_]+()", pos)
  if pos == nil then pos = str:len() + 1 end
  return pos
end

local function prevwordpos(str, pos)
  local pos = nextwordpos(str:reverse(), str:len() - pos + 2) - 1
  return str:len() - pos + 1
end

function Stdin:goword(dir)
  local fn = nextwordpos
  if dir < 0 then fn = prevwordpos end

  local pos = fn(self:tostring(), self.pos)
  self.pos = pos
end

function Stdin:delword(dir)
  if dir > 0 then
    local pos = nextwordpos(self:tostring(), self.pos)
    pos = pos - 1
    for i = self.pos, pos do
      table.remove(self.chars, self.pos)
    end
  else
    local pos = prevwordpos(self:tostring(), self.pos)
    for i = pos, self.pos - 1 do
      table.remove(self.chars, pos)
      self.pos = self.pos - 1
    end
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

  if partialcmd == nil then
    return
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

function Stdin:transposechar()
  if #self.chars < 2 or self.pos == 1 then return end
  local pos = self.pos
  if pos > #self.chars then pos = #self.chars end

  local tmp = self.chars[pos-1]
  self.chars[pos-1] = self.chars[pos]
  self.chars[pos] = tmp
end


repl = {}


--- repl.open([opts]) -> textgrid
--- Opens a new REPL; the `opts` parameter is an optional table with keys: inputcolor, stdoutcolor, resultcolor, backgroundcolor; these are 6-digit CSS-like hex strings.
function repl.open(opts)
  if repl._replwin then
    repl._replwin:show()
    repl._replwin:window():focus()
    return
  end

  local previousindockstate = hydra.indock()
  hydra.putindock(true)

  local win = textgrid.create()
  win:show()
  repl._replwin = win

  win:settitle("Hydra REPL")
  win:protect()

  local inputcolor = opts and opts.inputcolor or "00FF00"
  local backgroundcolor = opts and opts.backgroundcolor or "222222"
  local stdoutcolor = opts and opts.stdoutcolor or 'FF00FF'
  local resultcolor = opts and opts.resultcolor or '00FFFF'

  local scrollpos = 0

  local stdout = {}
  local stdin = Stdin.new()

  local function printline(win, line, gridwidth, y)
    if line == nil then return end
    local chars = utf8.chars(line.str)
    for x = 1, math.min(#chars, gridwidth) do
      win:setchar(chars[x], x, y)
      if line.kind == 'input' then
        win:setcharfg(inputcolor, x, y)
      elseif line.kind == 'printed' then
        win:setcharfg(stdoutcolor, x, y)
      elseif line.kind == 'result' then
        win:setcharfg(resultcolor, x, y)
      end
    end
  end

  local function printscrollback()
    local size = win:getsize()
    for y = 1, math.min(#stdout, size.h) do
      printline(win, stdout[y + scrollpos], size.w, y)
    end

    local promptlocation = #stdout - scrollpos + 1
    if promptlocation <= size.h then
      printline(win, {str = "> " .. stdin:tostring(), kind = 'input'}, size.w, promptlocation)
      win:setcharfg(backgroundcolor, 2 + stdin.pos, promptlocation)
      win:setcharbg(inputcolor, 2 + stdin.pos, promptlocation)
    end
  end

  local function restrictscrollpos()
    scrollpos = math.max(scrollpos, 0)
    scrollpos = math.min(scrollpos, #stdout)
  end

  local function redraw()
    win:setbg(backgroundcolor)
    win:setfg(inputcolor)
    win:clear()
    printscrollback()
  end

  local function ensurecursorvisible()
    local size = win:getsize()
    scrollpos = math.max(scrollpos, (#stdout+1) - size.h)
  end

  win:resized(redraw)

  local function appendstdout(line, kind)
    line = line:gsub("\t", "  ")
    table.insert(stdout, {str = line, kind = kind})
  end

  local function receivedlog(str)
    appendstdout(str, 'printed')
    redraw()
  end

  local loghandler = logger.addhandler(receivedlog)

  win:hidden(function()
      hydra.putindock(previousindockstate)
      logger.removehandler(loghandler)
  end)

  local function runcommand()
    local command = stdin:tostring()
    stdin:reset()
    stdin:addcommand(command)

    appendstdout("> " .. command, 'input')

    local fn, errmsg = load("return " .. command)
    if not fn then
      -- parsing failed, try without return
      fn, errmsg = load(command)
    end

    local resultstr
    if fn then
      -- parsed okay, execute it
      local results = table.pack(pcall(fn))

      local success = results[1]
      table.remove(results, 1)

      if success then
        for i = 1, results.n - 1 do results[i] = tostring(results[i]) end
        resultstr = table.concat(results, ", ")
      else
        resultstr = "error: " .. results[1]
      end
    else
      -- no fn, pass syntax error on
      resultstr = "syntax error: " .. errmsg
    end

    -- add each line separately
    for s in string.gmatch(resultstr, "[^\n]+") do
      appendstdout(s, 'result')
    end

    appendstdout("", 'result')
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

  local function gowordforward()
    stdin:goword(1)
    ensurecursorvisible()
  end

  local function gowordbackward()
    stdin:goword(-1)
    ensurecursorvisible()
  end

  local function delwordforward()
    stdin:delword(1)
    ensurecursorvisible()
  end

  local function delwordbackward()
    stdin:delword(-1)
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

  local function transposechar()
    stdin:transposechar()
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
    {"tab",    mods.none, function(t) end},
    {"delete", mods.none, delcharbackward},

    {"h", mods.ctrl, delcharbackward},
    {"d", mods.ctrl, delcharforward},

    {"p", mods.alt, scrollcharup},
    {"n", mods.alt, scrollchardown},

    {"p", mods.ctrl, historyprev},
    {"n", mods.ctrl, historynext},

    {"up",   mods.none, historyprev},
    {"down", mods.none, historynext},

    {"b", mods.ctrl, gocharbackward},
    {"f", mods.ctrl, gocharforward},

    {"b", mods.alt, gowordbackward},
    {"f", mods.alt, gowordforward},

    {"delete", mods.alt,  delwordbackward},
    {"w",      mods.ctrl, delwordbackward},
    {"d",      mods.alt,  delwordforward},

    {"a", mods.ctrl, golinefirst},
    {"e", mods.ctrl, golinelast},

    {"k", mods.ctrl, killtoend},

    {"t", mods.ctrl, transposechar},

    {"left",  mods.none, gocharbackward},
    {"right", mods.none, gocharforward},
  }

  local function handlekeypress(t)
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

  win:keydown(handlekeypress)

  redraw()
  win:focus()

  return win
end

-- I'm sorry. I'm sorry for writing such ugly code. I know it's a mess. I've always known. But it /works/.
