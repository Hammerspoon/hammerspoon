--- === hs.notify ===
---
--- Apple's built-in notifications system.
---
--- This module is based in part on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.notify.internal")

-- private variables and methods -----------------------------------------

local protected_functions = {
    show = true,
    release = true,
    withdraw = true,
    __index = true,
    __gc = true,
}

-- Public interface ------------------------------------------------------

--- hs.notify.new([fn,][attributes]) -> notification
--- Constructor
--- Returns a new notification object with the assigned callback function after applying the attributes specified in the attributes argument.  The attribute table can contain one or more key-value pairs where the key corrosponds to the short name of a notification attribute method.  The callback function receives as it's argument the notification object. Note that a notification with an empty title will not be delivered.
---
--- The notification attribute methods are:
---     title               subTitle
---     informativeText     soundName
---     alwaysPresent       autoWithdraw
---
--- Note that the following attributes only affect notifications if the user has set the Application notification type to "Alert" in the Notification Center System Preferences pane.
---     actionButtonTitle   otherButtonTitle
---     hasActionButton
module.new = function(fn, attributes)
    if type(fn) == "table" then
        attributes = fn
        fn = nil
    end
    fn = fn or function() end
    attributes = attributes or { title="Notification" }

    local note = module._new(fn)
    for i,v in pairs(attributes) do
        if getmetatable(note)[i] and not protected_functions[i] then
            note[i](note, v)
        end
    end
    return note
end

-- ----- What follows is to mimic hs.notify and actually could replace it if this module is added to core as something else.

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

--- hs.notify.show(title, subtitle, information, tag) -> notfication
--- Constructor
--- This function and it's supporting functions are deprecated and are provided only for convenience in migrating from Mjolnir or Hydra.  You are encouraged to use the `hs.notify.notification.new` function instead.
---
--- Convienence function to mimic Hydra's notify.show. Shows an Apple notification. Tag is a unique string that identifies this notification; any function registered for the given tag will be called if the notification is clicked. None of the strings are optional, though they may each be blank.
module.show = function(title, subtitle, information, tag)
    if type(title) ~= "string" or type(subtitle) ~= "string" or
        type(information) ~= "string" or type(tag) ~= "string" then
        error("All four arguments to hs.notify.show must be present and must be strings.",2)
        return nil
    else
        return module.new(function(note)
                callback(tag)
                note:withdraw()
            end, {
                title = title,
                subtitle = subtitle,
                informativeText = information,
            }):send()
    end
end

--- hs.notify.registry[]
--- Variable
--- This table contains the list of registered tags and their functions.  It should not be modified directly, but instead by the hs.notify.register(tag, fn) and hs.notify.unregister(id) functions.
module.registry = {}
module.registry.n = 0

--- hs.notify.register(tag, fn) -> id
--- Function
--- Registers a function to be called when an Apple notification with the given tag is clicked.
module.register = function(tag, fn)
  local id = module.registry.n + 1
  module.registry[id] = {tag, fn}
  module.registry.n = id
  return id
end

--- hs.notify.unregister(id)
--- Function
--- Unregisters a function to no longer be called when an Apple notification with the given tag is clicked.  Note that this uses the `id` returned by `hs.notify.notification.register`.
module.unregister = function(id)
  module.registry[id] = nil
end

--- hs.notify.notification.unregisterall()
--- Function
--- Unregisters all functions registered for notification-clicks.
module.unregisterall = function()
  module.registry = {}
  module.registry.n = 0
end

-- Return Module Object --------------------------------------------------

return module
