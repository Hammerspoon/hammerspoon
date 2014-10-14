--- === hs.notification ===
---
--- Home: https://github.com/asmagill/mjolnir_asm.ui
---
--- Apple's built-in notifications system.
---
--- This module is based in part on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.notification.internal")

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

local protected_functions = {
	_new = true,
	show = true,
	release = true,
	withdraw = true,
	__index = true,
	__gc = true,
}

-- Public interface ------------------------------------------------------

local actions = {}
for i,v in pairs(module.activationType) do actions[v] = i end
for i,v in pairs(actions) do module.activationType[i] = v end

--- hs.notification.new([fn,][attributes]) -> notification
--- Constructor
--- Returns a new notification object with the assigned callback function after applying the attributes specified in the attributes argument.  The attribute table can contain one or key-value pairs where the key corrosponds to the short name of a notification attribute function.  The callback function receives as it's argument the notification object. Note that a notification without an empty title will not be delivered.
module.new = function(fn, attributes)
    if type(fn) == "table" then
        attributes = fn
        fn = nil
    end
    fn = fn or function() end
	attributes = attributes or { title="Notification" }

    local note = module._new(wrap(fn))
	for i,v in pairs(attributes) do
		if getmetatable(note)[i] and not protected_functions[i] then
			note[i](note, v)
		end
	end
	return note
end

--- hs.notification.show(title, subtitle, information, tag) -> notfication
--- Constructor
--- Convienence function to mimic Hydra's notify.show. Shows an Apple notification. Tag is a unique string that identifies this notification; any functions registered for the given tag will be called if the notification is clicked. None of the strings are optional, though they may each be blank.
module.show = function(title, subtitle, information, tag)
    return module.new(function(note)
            callback(tag)
            note:withdraw()
        end, {
	    	title = title,
		    subtitle = subtitle,
		    informativeText = information,
	    }):send()
end

--- hs.notification.registry[]
--- Variable
--- This table contains the list of registered tags and their functions.  It should not be modified directly, but instead by the hs.notification.register(tag, fn) and hs.notification.unregister(id) functions.
module.registry = {}
module.registry.n = 0

--- hs.notification.register(tag, fn) -> id
--- Function
--- Registers a function to be called when an Apple notification with the given tag is clicked.
module.register = function(tag, fn)
  local id = module.registry.n + 1
  module.registry[id] = {tag, wrap(fn)}
  module.registry.n = id
  return id
end

--- hs.notification.unregister(id)
--- Function
--- Unregisters a function to no longer be called when an Apple notification with the given tag is clicked.  Note that this uses the `id` returned by `hs.register`.
module.unregister = function(id)
  module.registry[id] = nil
end

--- hs.notification.unregisterall()
--- Function
--- Unregisters all functions registered for notification-clicks; called automatically when user config reloads.
module.unregisterall = function()
  module.registry = {}
  module.registry.n = 0
end

-- Return Module Object --------------------------------------------------

return module

