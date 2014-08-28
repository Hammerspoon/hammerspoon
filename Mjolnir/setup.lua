os.exit = core.exit

function core.runstring(s)
  local fn, err = load("return " .. s)
  if not fn then fn, err = load(s) end
  if not fn then return tostring(err) end

  local str = ""
  local results = table.pack(pcall(fn))
  for i = 2,results.n do
    if i > 2 then str = str .. "\t" end
    str = str .. tostring(results[i])
  end
  return str
end

function _corelerrorhandler(err)
  return core.errorhandler(err)
end

function core.errorhandler(err)
  core._notify("Mjolnir error occurred")
  print(err)
  print(debug.traceback())
  return err
end

function core.pcall(f, ...)
  return xpcall(f, core.errorhandler, ...)
end

local rawprint = print
function print(...)
  rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  -- using table.concat here is safe, because we just stringified all the values
  local str = table.concat(vals, "\t") .. "\n"
  core._logmessage(str)
end

--- core.resetters = {}
--- If extensions need to reset any state when the user's config reloads, they must add a resetter function here.
--- i.e. core.hotkey's init.lua file should run `core.resetters["core.hotkey"] = function() ... end` at some point.
core.resetters = {}

local function resetstate()
  for _, fn in pairs(core.resetters) do
    fn()
  end
end

--- core.reload()
--- Reloads your init-file. Clears any state from extensions, i.e. disables all hotkeys, etc.
function core.reload()
  local fn, err = loadfile "init.lua"
  if fn then
    resetstate()
    if core.pcall(fn) then
      print "-- Ran ~/.mjolnir/init.lua; success."
    end
  elseif err:find "No such file or directory" then
    print "-- Cannot find ~/.mjolnir/init.lua; skipping."
  else
    print(tostring(err))
    core._notify("Syntax error in ~/.mjolnir/init.lua")
  end
end
