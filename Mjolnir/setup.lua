os.exit = mj._exit

function mj.runstring(s)
  local fn, err = loadstring("return " .. s)
  if not fn then fn, err = loadstring(s) end
  if not fn then return tostring(err) end

  local str = ""
  local results = table.pack(pcall(fn))
  for i = 2,results.n do
    if i > 2 then str = str .. "\t" end
    str = str .. tostring(results[i])
  end
  return str
end

function mj.showerror(err)
  mj._notify("Mjolnir error occurred")
  print(err)
end

do
  local r = debug.getregistry()
  r.__mj_debug_traceback = debug.traceback
  r.__mj_showerror = mj.showerror
end

local rawprint = print
function print(...)
  rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  local str = table.concat(vals, "\t") .. "\n"
  mj._logmessage(str)
end

--- mj.print = print
--- The original print function, before Mjolnir overrides it.
mj.print = rawprint


-- load user's init-file
local fn, err = loadfile "init.lua"
if fn then
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    print "-- Loading ~/.mjolnir/init.lua; success."
  else
    mj.showerror(err)
  end
elseif err:find "No such file or directory" then
  print "-- Loading ~/.mjolnir/init.lua; file not found, skipping."
else
  print(tostring(err))
  mj._notify("Syntax error in ~/.mjolnir/init.lua")
end
