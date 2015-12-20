local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...

os.exit = hs._exit

local function runstring(s)
  local fn, err = load("return " .. s)
  if not fn then fn, err = load(s) end
  if not fn then return tostring(err) end

  local str = ""
  local results = table.pack(xpcall(fn,debug.traceback))
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
---  * This function is called whenever an (uncaught) error occurs or is thrown (via `error()`)
---  * The default implementation shows a notification, opens the Console, and prints the error message and stacktrace
---  * You can override this function if you wish to route errors differently (e.g. for remote systems)

function hs.showError(err)
  hs._notify("Hammerspoon config error") -- undecided on this line
  --  print(debug.traceback())
  print(err)
  hs.focus()
  hs.openConsole()
  hs._TERMINATED=true
end

function hs.assert(pred,desc,data)
  if not pred then error([[
Internal error: please open an issue at
https://github.com/Hammerspoon/hammerspoon/issues/new   and paste the following stack trace:

Assertion failed: ]]..desc..'\n'..(data and hs.inspect(data) or ''),2)
  end
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

os.exit = hs._exit

local function runstring(s)
  local fn, err = load("return " .. s)
  if not fn then fn, err = load(s) end
  if not fn then return tostring(err) end

  local str = ""
  local results = table.pack(xpcall(fn,debug.traceback))
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

--- hs.shutdownCallback
--- Variable
--- An optional function that will be called when the Lua environment is being destroyed (either because Hammerspoon is exiting or reloading its config)
--- Notes:
---  * This function should not perform any asynchronous tasks
---  * You do not need to fastidiously destroy objects you have created, this callback exists purely for utility reasons (e.g. serialising state, destroying system resources that will not be released by normal Lua garbage collection processes, etc)
hs.shutdownCallback = nil

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
---  * This function is called whenever an (uncaught) error occurs or is thrown (via `error()`)
---  * The default implementation shows a notification, opens the Console, and prints the error message and stacktrace
---  * You can override this function if you wish to route errors differently (e.g. for remote systems)

function hs.showError(err)
  hs._notify("Hammerspoon config error") -- undecided on this line
  --  print(debug.traceback())
  print(err)
  hs.focus()
  hs.openConsole()
  hs._TERMINATED=true
end

function hs.assert(pred,desc,data)
  if not pred then error([[
Internal error: please open an issue at
https://github.com/Hammerspoon/hammerspoon/issues/new   and paste the following stack trace:

Assertion failed: ]]..desc..'\n'..(data and hs.inspect(data) or ''),2)
  end
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
return require'hs._coresetup'(...)
