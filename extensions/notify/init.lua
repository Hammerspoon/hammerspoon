--- === hs.notify ===
---
--- Apple's built-in notifications system.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.notify.internal")

-- private variables and methods -----------------------------------------

local function callback(tag)
  for k, v in pairs(module.registry) do
    if k ~= "n" and v ~= nil then
      local fntag, fn = v[1], v[2]
      if tag == fntag then
        fn()
      end
    end
  end
end

local function wrap(fn)
  return function(...)
    if fn then
      local ok, err = xpcall(fn, debug.traceback, ...)
      if not ok then hs.showerror(err) end
    end
  end
end


-- Public interface ------------------------------------------------------

--- hs.notify.registry[]
--- Variable
--- This table contains the list of registered tags and their functions.  It should not be modified directly, but instead by the hs.notify.register(tag, fn) and hs.notify.unregister(id) functions.
module.registry = {}
module.registry.n = 0

setmetatable(module.registry, { __gc = module.withdrawAll })

if not _notifysetup then
  module._setup(callback)
  _notifysetup = true
end

--- hs.notify.register(tag, fn) -> id
--- Function
--- Registers a function to be called when an Apple notification with the given tag is clicked.
module.register = function(tag, fn)
  local id = module.registry.n + 1
  module.registry[id] = {tag, wrap(fn)}
  module.registry.n = id
  return id
end

--- hs.notify.unregister(id)
--- Function
--- Unregisters a function to no longer be called when an Apple notification with the given tag is clicked.
module.unregister = function(id)
  module.registry[id] = nil
end

--- hs.notify.unregisterall()
--- Function
--- Unregisters all functions registered for notification-clicks; called automatically when user config reloads.
module.unregisterall = function()
  module.registry = {}
  module.registry.n = 0
end

-- Return Module Object --------------------------------------------------

return module

