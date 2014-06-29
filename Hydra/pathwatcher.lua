pathwatcher.pathwatchers = {}
pathwatcher.pathwatchers.n = 0

-- doc.pathwatcher.new = {"pathwatcher.new(path, fn())", "Returns a new pathwatcher that can be started and stopped. Contains fields: path, fn."}
function pathwatcher.new(path, fn)
  return setmetatable({path = path, fn = fn}, {__index = pathwatcher})
end

-- doc.pathwatcher.start = {"pathwatcher:start()", "Registers pathwatcher's fn as a callback when pathwatcher's path or any descendent changes."}
function pathwatcher:start()
  local id = pathwatcher.pathwatchers.n + 1
  self.__id = id

  pathwatcher.pathwatchers[id] = self
  pathwatcher.pathwatchers.n = id

  return self:_start()
end

-- doc.pathwatcher.stop = {"pathwatcher:stop()", "Unregisters pathwatcher's fn so it won't be called again until the pathwatcher is restarted."}
function pathwatcher:stop()
  pathwatcher.pathwatchers[self.__id] = nil
  return self:_stop()
end

-- doc.pathwatcher.stopall = {"pathwatcher.stopall()", "Calls p:stop() for all started pathwatchers; called automatically when user config reloads."}
function pathwatcher.stopall()
  for i, pw in pairs(pathwatcher.pathwatchers) do
    if pw and i ~= "n" then pw:stop() end
  end
  pathwatcher.pathwatchers.n = 0
end
