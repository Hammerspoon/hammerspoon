--- === hs.notify ===
---
--- On-screen notifications using Notification Center
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
--- Creates a new notification object
---
--- Parameters:
---  * fn - An optional function, which will be called when the user interacts with notifications. The notification object will be passed as an argument to the function.
---  * attributes - An optional table for applying attributes to the notification. Possible keys are:
---   * title
---   * subTitle
---   * informativeText
---   * soundName
---   * alwaysPresent
---   * autoWithdraw
---   * actionButtonTitle (only available if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences)
---   * otherButtonTitle (only available if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences)
---   * hasActionButton (only available if the user has set Hammerspoon notifications to `Alert` in the Notification Center pane of System Preferences)
---
--- Returns:
---  * A notification object
---
--- Notes:
---  * If a notification does not have a `title` attribute set, OS X will not display it. Either use the `title` key in the attributes table, or call `hs.notify:title()` before displaying the notification
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

--- hs.notify._DEPRECATED
--- Deprecated
--- Previous versions of Hammerspoon, Mjolnir and Hydra included a much less rich notification API. This old API is still available in Hammerspoon, but you should migrate all of your usage of the following APIs, to the newer ones documented below, as soon as possible.
---
--- * hs.notify.show(title, subtitle, information, tag) -> notfication
---  * Constructor
---  * Convienence function to mimic Hydra's notify.show. Shows an Apple notification. Tag is a unique string that identifies this notification; any function registered for the given tag will be called if the notification is clicked. None of the strings are optional, though they may each be blank.
---
--- * hs.notify.registry[]
---  * Variable
---  * This table contains the list of registered tags and their functions.  It should not be modified directly, but instead by the hs.notify.register(tag, fn) and hs.notify.unregister(id) functions.
---
--- * hs.notify.register(tag, fn) -> id
---  * Function
---  * Registers a function to be called when an Apple notification with the given tag is clicked.
---
--- * hs.notify.unregister(id)
---  * Function
---  * Unregisters a function to no longer be called when an Apple notification with the given tag is clicked.  Note that this uses the `id` returned by `hs.notify.notification.register`.
---
--- * hs.notify.notification.unregisterall()
---  * Function
---  * Unregisters all functions registered for notification-clicks.
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

module.registry = {}
module.registry.n = 0

module.register = function(tag, fn)
  local id = module.registry.n + 1
  module.registry[id] = {tag, fn}
  module.registry.n = id
  return id
end

module.unregister = function(id)
  module.registry[id] = nil
end

module.unregisterall = function()
  module.registry = {}
  module.registry.n = 0
end

-- Return Module Object --------------------------------------------------

return module
