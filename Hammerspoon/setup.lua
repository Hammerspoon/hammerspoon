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
--  print(debug.traceback())
--  print(err)
  print(debug.traceback(err, 2))
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

--- hs.execute(command[, with_user_env]) -> output, status, type, rc
--- Function
--- Runs a shell command, optionally loading the users shell environment first, and returns stdout as a string, followed by the same result codes as `os.execute` would return.
---
--- Parameters:
---  * command - a string containing the shell command to execute
---  * with_user_env - optional boolean argument which if provided and is true, executes the command in the users login shell as an "interactive" login shell causing the user's local profile (or other login scripts) to be loaded first.
---
--- Returns:
---  * output -- the stdout of the command as a string.  May contain an extra terminating new-line (\n).
---  * status -- `true` if the command terminated successfully or nil otherwise.
---  * type   -- a string value of "exit" or "signal" indicating whether the command terminated of its own accord or if it was terminated by a signal (killed, segfault, etc.)
---  * rc     -- if the command exited of its own accord, then this number will represent the exit code (usually 0 for success, not 0 for an error, though this is very command specific, so check man pages when there is a question).  If the command was killed by a signal, then this number corresponds to the signal type that caused the command to terminate.
---
--- Notes:
---  * Setting `with_user_env` to true does incur noticeable overhead, so it should only be used if necessary (to set the path or other environment variables).
---  * Because this function returns the stdout as it's first return value, it is not quite a drop-in replacement for `os.execute`.  In most cases, it is probable that `stdout` will be the empty string when `status` is nil, but this is not guaranteed, so this trade off of shifting os.execute's results was deemed acceptable.
---  * This particular function is most useful when you're more interested in the command's output then a simple check for completion and result codes.  If you only require the result codes or verification of command completion, then `os.execute` will be slightly more efficient.
hs.execute = function(command, user_env)
    local f
    if user_env then
        f = io.popen(os.getenv("SHELL")..[[ -l -i -c "]]..command..[["]], 'r')
    else
        f = io.popen(command, 'r')
    end
    local s = f:read('*a')
    local status, exit_type, rc = f:close()
    return s, status, exit_type, rc
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
      if (extension ~= ".") and (extension ~= "..") and (string.sub(extension, -6) ~= ".dylib") then
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

--- hs.dockIcon([state]) -> bool
--- Function
--- Set or display whether or not the Hammerspoon dock icon is visible.
---
--- Parameters:
---  * state - an optional boolean which will set whether or not the Hammerspoon dock icon should be visible.
---
--- Returns:
---  * True if the icon is currently set (or has just been) to be visible or False if it is not.
---
--- Notes:
---  * This function is a wrapper to functions found in the `hs.dockicon` module, but is provided here to provide an interface consistent with other selectable preference items.
hs.dockIcon = function(value)
    local hsdi = require("hs.dockicon")
    if type(value) == "boolean" then
        if value then hsdi.show() else hsdi.hide() end
    end
    return hsdi.visible()
end

--- hs.help(identifier)
--- Function
--- Prints the documentation for some part of Hammerspoon's API and Lua 5.3.  This function is actually sourced from hs.doc.help.
---
--- Parameters:
---  * identifier - A string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`)
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is mainly for runtime API help while using Hammerspoon's Console
---
---  * You can also access the results of this function by the following methods from the console:
---    * help("identifier") -- quotes are required, e.g. `help("hs.reload")`
---    * help.identifier.path -- no quotes are required, e.g. `help.hs.reload`
---
---  * Lua information can be accessed by using the `lua` prefix, rather than `hs`.
---    * the identifier `lua._man` provides the table of contents for the Lua 5.3 manual.  You can pull up a specific section of the lua manual by including the chapter (and subsection) like this: `lua._man._3_4_8`.
---    * the identifier `lua._C` will provide information specifically about the Lua C API for use when developing modules which require external libraries.

hs.help = require("hs.doc")
help = hs.help

if not hasinitfile then
  hs.notify.register("__noinitfile", function() os.execute("open http://www.hammerspoon.org/go/") end)
  hs.notify.show("Hammerspoon", "No config file found", "Click here for the Getting Started Guide", "__noinitfile")
  print(string.format("-- Can't find %s; create it and reload your config.", prettypath))
  return runstring
end

local hscrash = require("hs.crash")
rawrequire = require
require = function(modulename)
    local result = rawrequire(modulename)
    pcall(function()
            hscrash.crashLog("require('"..modulename.."')")
            if string.sub(modulename, 1, 3) == "hs." then
                -- Reasonably certain that we're dealing with a Hammerspoon extension
                local extname = string.sub(modulename, 4, -1)
                for k,v in ipairs(hscrash.dumpCLIBS()) do
                    if string.find(v, extname) then
                        hscrash.crashLog("  Candidate CLIBS match: "..v)
                    end
                end
            end
            if string.sub(modulename, 1, 8) == "mjolnir." then
                -- Reasonably certain that we're dealing with a Mjolnir module
                local mjolnirmod = string.sub(modulename, 9, -1)
                local mjolnirrep = {"application", "hotkey", "screen", "geometry", "fnutils", "keycodes", "alert", "cmsj.appfinder", "_asm.ipc", "_asm.modal_hotkey", "_asm.settings", "7bits.mjomatic", "_asm.eventtap.event", "_asm.timer", "_asm.pathwatcher", "_asm.eventtap", "_asm.notify", "lb.itunes", "_asm.utf8_53", "cmsj.caffeinate", "lb.spotify", "_asm.sys.mouse", "_asm.sys.battery", "_asm.ui.sound", "_asm.data.base64", "_asm.data.json"}
                for _,v in pairs(mjolnirrep) do
                    if v == mjolnirmod then
                        hscrash.crashKV("MjolnirModuleLoaded", "YES")
                        break
                    end
                end
            end
          end)
    return result
end
hscrash.crashLog("Loaded from: "..modpath)

print("-- Loading " .. prettypath)
local fn, err = loadfile(fullpath)
if not fn then hs.showError(err) return runstring end

local ok, err = xpcall(fn, debug.traceback)
if not ok then hs.showError(err) return runstring end

print "-- Done."

return runstring
