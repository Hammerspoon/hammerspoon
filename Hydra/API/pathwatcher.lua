--- pathwatcher
---
--- Watch paths recursively for changes.
---
--- This simple example watches your Hydra directory for changes, and when it sees a change, reloads your configs:
---
---     pathwatcher.new(os.getenv("HOME") .. "/.hydra/", hydra.reload):start()


pathwatcher.pathwatchers = {}
pathwatcher.pathwatchers.n = 0

--- pathwatcher.new(path, fn())
--- Returns a new pathwatcher that can be started and stopped. Contains fields: path, fn.
function pathwatcher.new(path, fn)
  return setmetatable({path = path, fn = fn}, {__index = pathwatcher})
end

--- pathwatcher:start()
--- Registers pathwatcher's fn as a callback when pathwatcher's path or any descendent changes.
function pathwatcher:start()
  local id = pathwatcher.pathwatchers.n + 1
  self.__id = id

  pathwatcher.pathwatchers[id] = self
  pathwatcher.pathwatchers.n = id

  self.__stream, self.__closure = pathwatcher._start(self.path, self.fn)
end

--- pathwatcher:stop()
--- Unregisters pathwatcher's fn so it won't be called again until the pathwatcher is restarted.
function pathwatcher:stop()
  pathwatcher.pathwatchers[self.__id] = nil
  pathwatcher._stop(self.__stream, self.__closure)
end

--- pathwatcher.stopall()
--- Calls p:stop() for all started pathwatchers; called automatically when user config reloads.
function pathwatcher.stopall()
  for i, pw in pairs(pathwatcher.pathwatchers) do
    if pw and i ~= "n" then pw:stop() end
  end
  pathwatcher.pathwatchers.n = 0
end
