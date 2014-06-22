api.pathwatcher.pathwatchers = {}

function api.pathwatcher:start()
  table.insert(api.pathwatcher.pathwatchers, self)
  self.__pos = # api.pathwatcher.pathwatchers
  return self:_start()
end

function api.pathwatcher:stop()
  table.remove(api.pathwatcher.pathwatchers, self.__pos)
  return self:_stop()
end
