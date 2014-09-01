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

--- mjolnir.showerror(err)
--- Function
--- Presents an error to the user via Mjolnir's GUI.
--- Useful for writing modules that take callbacks from the user, e.g.:
---     local ok, err = xpcall(callbackfn, debug.traceback)
---     if not ok then mjolnir.showerror(err) end
function mjolnir.showerror(err)
  mjolnir._notify("Mjolnir error occurred")
  print(err)
end

do
  local r = debug.getregistry()
  r.__mj_debug_traceback = debug.traceback
  r.__mj_showerror = mjolnir.showerror
end

local rawprint = print
function print(...)
  rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  local str = table.concat(vals, "\t") .. "\n"
  mjolnir._logmessage(str)
end

--- mjolnir.print = print
--- Function
--- The original print function, before Mjolnir overrides it.
mjolnir.print = rawprint


-- load user's init-file
print "-- Loading ~/.mjolnir/init.lua"

local fn, err = loadfile "init.lua"
if fn then
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    print "-- Success."
  else
    mjolnir.showerror(err)
  end
elseif err:find "No such file or directory" then
  print "-- File not found: ~/.mjolnir/init.lua; skipping."
else
  print "-- Syntax error:"
  print(tostring(err))
  mjolnir._notify("Syntax error in ~/.mjolnir/init.lua")
end
