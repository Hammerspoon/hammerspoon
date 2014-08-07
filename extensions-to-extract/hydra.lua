-- local function clear_old_state()
--   hydra.menu.hide()
--   hotkey.disableall()
--   pathwatcher.stopall()
--   timer.stopall()
--   textgrid.destroyall()
--   notify.unregisterall()
--   notify.applistener.stopall()
--   battery.watcher.stopall()
--   eventtap.stopall()
-- end

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
