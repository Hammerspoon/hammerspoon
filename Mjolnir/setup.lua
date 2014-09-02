local prettypath, fullpath, configdir, hasinitfile = ...

os.exit = mjolnir._exit

function mjolnir.runstring(s)
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

--- mjolnir.configdir = "~/.mjolnir/"
--- Constant
--- The user's Mjolnir config directory. Modules may use it, assuming
--- they've worked out a contract with the user about how to use it.
mjolnir.configdir = configdir

--- mjolnir.showerror(err)
--- Function
--- Presents an error to the user via Mjolnir's GUI.
--- Useful for writing modules that take callbacks from the user, e.g.:
---
---     local ok, err = xpcall(callbackfn, debug.traceback)
---     if not ok then mjolnir.showerror(err) end
function mjolnir.showerror(err)
  mjolnir._notify("Mjolnir error occurred")
  print(err)
end

--- mjolnir.rawprint = print
--- Function
--- The original print function, before Mjolnir overrides it.
local rawprint = print
mjolnir.rawprint = rawprint
function print(...)
  rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  local str = table.concat(vals, "\t") .. "\n"
  mjolnir._logmessage(str)
end

if not hasinitfile then
  print(string.format("-- Can't find %s; create it and reload your config.", prettypath))
  return
end

print("-- Loading " .. prettypath)
local fn, err = loadfile(fullpath)
if not fn then mjolnir.showerror(err) return end

local ok, err = xpcall(fn, debug.traceback)
if not ok then mjolnir.showerror(err) return end

print "-- Done."
