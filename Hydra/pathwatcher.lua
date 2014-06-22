api.pathwatcher.pathwatchers = {}

local internal_start =  api.pathwatcher.start
local internal_stop =  api.pathwatcher.stop

function api.pathwatcher.start(pw)
  table.insert(api.pathwatcher.pathwatchers, pw)
  pw.__pos = # api.pathwatcher.pathwatchers
  internal_start(pw)
end

function api.pathwatcher.stop(pw)
  table.remove(api.pathwatcher.pathwatchers, pw.__pos)
  internal_stop(pw)
end
