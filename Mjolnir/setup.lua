local modpath, prettypath, fullpath, configdir, hasinitfile = ...

os.exit = mjolnir._exit

local function runstring(s)
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
---
--- Presents an error to the user via Mjolnir's GUI. The default
--- implementation prints the error, focuses Mjolnir, and opens
--- Mjolnir's console.
---
--- Users can override this with a new function that shows errors in a
--- custom way.
---
--- Modules can call this in the event of an error, e.g. in callbacks
--- from the user:
---
---     local ok, err = xpcall(callbackfn, debug.traceback)
---     if not ok then mjolnir.showerror(err) end
function mjolnir.showerror(err)
  mjolnir._notify("Mjolnir error occurred") -- undecided on this line
  print(err)
  mjolnir.focus()
  mjolnir.openconsole()
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
  return runstring
end

print("-- Augmenting require paths")
package.path=package.path..";"..modpath.."/?.lua"
package.cpath=package.cpath..";"..modpath.."/?.so"

print("-- Loading " .. prettypath)
local fn, err = loadfile(fullpath)
if not fn then mjolnir.showerror(err) return runstring end

local ok, err = xpcall(fn, debug.traceback)
if not ok then mjolnir.showerror(err) return runstring end

print "-- Done."

return runstring
