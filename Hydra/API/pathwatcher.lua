--- pathwatcher.stopall()
--- Calls pathwatcher:stop() for all started pathwatchers; called automatically when user config reloads.
function pathwatcher.stopall()
  local pws = fnutils.filter(_registry, hydra._ishandlertypefn("pathwatcher"))
  fnutils.each(pws, pathwatcher.stop)
end
