local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

os.exit = hs._exit

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

--- hs.configdir = "~/.hammerspoon/"
--- Constant
--- The user's Hammerspoon config directory. Modules may use it, assuming
--- they've worked out a contract with the user about how to use it.
hs.configdir = configdir

--- hs.docstrings_json_file
--- Constant
--- This is the full path to the docs.json file shipped with Hammerspoon.
--- It contains the same documentation used to generate the full Hammerspoon
--- API documentation, in JSON form.
--- You can load, parse and access this information using the hs.doc extension
hs.docstrings_json_file = docstringspath

--- hs.showError(err)
--- Function
---
--- Presents an error to the user via Hammerspoon's GUI. The default
--- implementation prints the error, focuses Hammerspoon, and opens
--- Hammerspoon's console.
---
--- Users can override this with a new function that shows errors in a
--- custom way.
---
--- Modules can call this in the event of an error, e.g. in callbacks
--- from the user:
---
---     local ok, err = xpcall(callbackfn, debug.traceback)
---     if not ok then hs.showError(err) end
function hs.showError(err)
  hs._notify("Hammerspoon config error") -- undecided on this line
  print(err)
  hs.focus()
  hs.openConsole()
end

--- hs.rawprint = print
--- Function
--- The original print function, before hammerspoon overrides it.
local rawprint = print
hs.rawprint = rawprint
function print(...)
  rawprint(...)
  local vals = table.pack(...)

  for k = 1, vals.n do
    vals[k] = tostring(vals[k])
  end

  local str = table.concat(vals, "\t") .. "\n"
  hs._logmessage(str)
end

print("-- Augmenting require paths")
package.path=configdir.."/?.lua"..";"..configdir.."/?/init.lua"..";"..package.path..";"..modpath.."/?.lua"..";"..modpath.."/?/init.lua"
package.cpath=configdir.."/?.so"..";"..package.cpath..";"..modpath.."/?.so"

print("-- package.path:")
for part in string.gmatch(package.path, "([^;]+)") do
    print("      "..part)
end

print("-- package.cpath:")
for part in string.gmatch(package.cpath, "([^;]+)") do
    print("      "..part)
end

if autoload_extensions then
  print("-- Lazy extension loading enabled")
  hs._extensions = {}

  -- Discover extensions in our .app bundle
  local iter, dir_obj = require("hs.fs").dir(modpath.."/hs")
  local extension = iter(dir_obj)
  while extension do
      if (extension ~= ".") and (extension ~= "..") then
          hs._extensions[extension] = true
      end
      extension = iter(dir_obj)
  end

  -- Inject a lazy extension loader into the main HS table
  setmetatable(hs, {
      __index = function(t, key)
          if hs._extensions[key] ~= nil then
              print("-- Loading extension: "..key)
              hs[key] = require("hs."..key)
              return hs[key]
          else
              return nil
          end
      end
  })
end

function help(identifier)
  local doc = require "hs.doc"
  local tree = doc.from_json_file(hs.docstrings_json_file)
  local result = tree

  for word in string.gmatch(identifier, '([^.]+)') do
    result = result[word]
  end

  print(result)
end

if not hasinitfile then
  hs.notify.register("__noinitfile", function() os.execute("open http://www.hammerspoon.org/go/") end)
  hs.notify.show("Hammerspoon", "No config file found", "Click here for the Getting Started Guide", "__noinitfile")
  print(string.format("-- Can't find %s; create it and reload your config.", prettypath))
  return runstring
end

print("-- Loading " .. prettypath)
local fn, err = loadfile(fullpath)
if not fn then hs.showError(err) return runstring end

local ok, err = xpcall(fn, debug.traceback)
if not ok then hs.showError(err) return runstring end

print "-- Done."

return runstring
