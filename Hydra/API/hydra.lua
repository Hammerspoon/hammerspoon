--- === ext ===
---
--- Standard high-level namespace for third-party extensions.
ext = {}


local function clear_old_state()
  hydra.menu.hide()
  hotkey.disableall()
  pathwatcher.stopall()
  timer.stopall()
  textgrid.destroyall()
  notify.unregisterall()
  notify.applistener.stopall()
  battery.watcher.stopall()
end

local function load_default_config()
  clear_old_state()
  local fallbackinit = dofile(hydra.resourcesdir .. "/fallback_init.lua")
  fallbackinit.run()
end

--- hydra.reload()
--- Reloads your init-file. Makes sure to clear any state that makes sense to clear (hotkeys, pathwatchers, etc).
function hydra.reload()
  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local exists, isdir = hydra.fileexists(userfile)

  if exists and not isdir then
    local fn, err = loadfile(userfile)
    if fn then
      clear_old_state()
      local ok, err = pcall(fn)
      if not ok then
        notify.show("Hydra config runtime error", "", tostring(err) .. " -- Falling back to sample config.", "")
        load_default_config()
      end
    else
      notify.show("Hydra config syntax error", "", tostring(err) .. " -- Doing nothing.", "")
    end
  else
    -- don't say (via alert) anything more than what the default config already says
    load_default_config()
  end
end

--- hydra.errorhandler = function(err)
--- Error handler for hydra.call; intended for you to set, not for third party libs
function hydra.errorhandler(err)
  print("Error: " .. err)
  notify.show("Hydra Error", "", tostring(err), "error")
end

function hydra.tryhandlingerror(firsterr)
  local ok, seconderr = pcall(function()
      hydra.errorhandler(firsterr)
  end)

  if not ok then
    notify.show("Hydra error", "", "Error while handling error: " .. tostring(seconderr) .. " -- Original error: " .. tostring(firsterr), "")
  end
end

--- hydra.call(fn, ...) -> ...
--- Just like pcall, except that failures are handled using hydra.errorhandler
function hydra.call(fn, ...)
  local results = table.pack(pcall(fn, ...))
  if not results[1] then
    -- print(debug.traceback())
    hydra.tryhandlingerror(results[2])
  end
  return table.unpack(results)
end

--- hydra.exec(command) -> string
--- Runs a shell function and returns stdout as a string (may include trailing newline).
function hydra.exec(command)
  local f = io.popen(command)
  local str = f:read('*a')
  f:close()
  return str
end

--- hydra.version -> string
--- The current version of Hydra, as a human-readable string.
hydra.version = hydra.updates.currentversion()

--- hydra.licenses -> string
--- Returns a string containing the licenses of all the third party software Hydra uses (i.e. Lua)
hydra.licenses = [[
### Lua 5.2

Copyright (c) 1994-2014 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### inspect

Copyright (c) 2013 Enrique García Cota

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]

-- swizzle! this is necessary so hydra.settings can save keys on exit
os.exit = hydra.exit
