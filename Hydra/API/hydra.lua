--- ext
---
--- Standard high-level namespace for third-party extensions.
ext = {}


local function clear_old_state()
  hotkey.disableall()
  menu.hide()
  pathwatcher.stopall()
  timer.stopall()
  textgrid.destroyall()
  notify.unregisterall()
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

local function trimstring(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

--- hydra.exec(command) -> string
--- Runs a shell function and returns stdout as a string (without trailing newline).
function hydra.exec(command)
  local f = io.popen(command)
  local str = f:read("*a")
  f:close()
  return trimstring(str)
end

--- hydra.uuid() -> string
--- Returns a UUID as a string
function hydra.uuid()
  return hydra.exec("uuidgen")
end

-- swizzle! this is necessary so hydra.settings can save keys on exit
os.exit = hydra.exit
