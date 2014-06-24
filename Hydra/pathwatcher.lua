api.pathwatcher.pathwatchers = {}
api.pathwatcher.pathwatchers.n = 0

doc.api.pathwatcher.new = {"api.pathwatcher.new(path, fn())", "Returns a new pathwatcher that can be started and stopped. Contains fields: path, fn."}
function api.pathwatcher.new(path, fn)
  return setmetatable({path = path, fn = fn}, {__index = api.pathwatcher})
end

doc.api.pathwatcher.start = {"api.pathwatcher:start()", "Registers pathwatcher's fn as a callback when pathwatcher's path or any descendent changes."}
function api.pathwatcher:start()
  local id = api.pathwatcher.pathwatchers.n + 1
  self.__id = id

  api.pathwatcher.pathwatchers[id] = self
  api.pathwatcher.pathwatchers.n = id

  return self:_start()
end

doc.api.pathwatcher.stop = {"api.pathwatcher:stop()", "Unregisters pathwatcher's fn so it won't be called again until the pathwatcher is restarted."}
function api.pathwatcher:stop()
  api.pathwatcher.pathwatchers[self.__id] = nil
  return self:_stop()
end

doc.api.pathwatcher.stopall = {"api.pathwatcher.stopall()", "Calls p:stop() for all started pathwatchers; called automatically when user config reloads."}
function api.pathwatcher.stopall()
  for i, pw in pairs(api.pathwatcher.pathwatchers) do
    if pw and i ~= "n" then pw:stop() end
  end
  api.pathwatcher.pathwatchers.n = 0
end
