os.exit = mj.exit

package.path = package.path .. ';' .. './ext/?/init.lua'

local function pack(...)
  {n = select("#", ...), ...}
end

function mj.runstring(s)
  local fn, err = load("return " .. s)
  if not fn then fn, err = load(s) end
  if not fn then return tostring(err) end

  local str = ""
  local results = pack(pcall(fn))
  for i = 2,results.n do
    if i > 2 then str = str .. "\t" end
    str = str .. tostring(results[i])
  end
  return str
end

function _mjerrorhandler(err)
  return mj.errorhandler(err)
end

function mj.errorhandler(err)
  mj._notify("Mjolnir error occurred")
  print(err)
  print(debug.traceback())
  return err
end

function mj.pcall(f, ...)
  return xpcall(f, mj.errorhandler, ...)
end

local rawprint = print
function print(...)
  rawprint(...)
  local vals = pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  -- using table.concat here is safe, because we just stringified all the values
  local str = table.concat(vals, "\t") .. "\n"
  mj._logmessage(str)
end

--- mj.reload()
--- Reloads your init-file. Clears any state from extensions, i.e. disables all hotkeys, etc.
function mj.reload()
  local fn, err = loadfile "init.lua"
  if fn then
    if mj.pcall(fn) then
      print "-- Load user settings: success."
    end
  elseif err:find "No such file or directory" then
    print "-- Load personal settings: cannot find ~/.mjolnir/init.lua; skipping."
    print "-- See the documentation for more info about init.lua"
  else
    print(tostring(err))
    mj._notify("Syntax error in ~/.mjolnir/init.lua")
  end
end
