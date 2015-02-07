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

--- hs.configdir
--- Constant
--- A string containing Hammerspoon's configuration directory. Typically `~/.hammerspoon/`
hs.configdir = configdir

--- hs.docstrings_json_file
--- Constant
--- A string containing the full path to the `docs.json` file inside Hammerspoon's app bundle. This contains the full Hammerspoon API documentation and can be accessed in the Console using `help("someAPI")`. It can also be loaded and processed by the `hs.doc` extension
hs.docstrings_json_file = docstringspath

--- hs.showError(err)
--- Function
--- Shows an error to the user, using Hammerspoon's Console
---
--- Parameters:
---  * err - A string containing an error message
---
--- Returns:
---  * None
---
--- Notes:
---  * You can override this function if you wish to route errors differently
---  * Modules can call this in the event of an error, e.g. in callbacks from the user:
---
---     ```local ok, err = xpcall(callbackfn, debug.traceback)
---     if not ok then hs.showError(err) end```
function hs.showError(err)
  hs._notify("Hammerspoon config error") -- undecided on this line
  print(err)
  hs.focus()
  hs.openConsole()
end

--- hs.toggleConsole()
--- Function
--- Toggles the visibility of the console
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * If the console is not currently open, it will be opened. If it is open and not the focused window, it will be brought forward and focused.
---  * If the console is focused, it will be closed.
function hs.toggleConsole()
    local console = hs.appfinder.windowFromWindowTitle("Hammerspoon Console")
    if console and (console ~= hs.window.focusedWindow()) then
        console:focus()
    elseif console then
        console:close()
    else
        hs.openConsole()
    end
end

--- hs.rawprint(aString)
--- Function
--- The original Lua print() function
---
--- Parameters:
---  * aString - A string to be printed
---
--- Returns:
---  * None
---
--- Notes:
---  * Hammerspoon overrides Lua's print() function, but this is a reference we retain to is, should you need it for any reason
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

--- hs.help(identifier)
--- Function
--- Prints the documentation for some part of Hammerspoon's API
---
--- Parameters:
---  * identifier - A string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`)
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is mainly for runtime API help while using Hammerspoon's Console
---  * You can also just use `help()` directly
function hs.help(identifier)
  local doc = require "hs.doc"
  local tree = doc.fromJSONFile(hs.docstrings_json_file)
  local result = tree

  for word in string.gmatch(identifier, '([^.]+)') do
    result = result[word]
  end

  print(result)
end
help = hs.help

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
