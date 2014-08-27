-- local function clear_old_state()
--   pathwatcher.stopall()
--   timer.stopall()
--   textgrid.destroyall()
--   notify.unregisterall()
--   notify.applistener.stopall()
--   battery.watcher.stopall()
--   eventtap.stopall()
-- end

--- hydra.exec(command) -> string
--- Runs a shell function and returns stdout as a string (may include trailing newline).
function hydra.exec(command)
  local f = io.popen(command)
  local str = f:read('*a')
  f:close()
  return str
end
