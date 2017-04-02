
--- === hs.notify ===
---
--- This module allows you to create on screen notifications in the User Notification Center located at the right of the users screen.
---
--- Notifications can be sent immediately or scheduled for delivery at a later time, even if that scheduled time occurs when Hammerspoon is not currently running. Currently, if you take action on a notification while Hammerspoon is not running, the callback function is not honored for the first notification clicked upon -- This is expected to be fixed in a future release.
---
--- When setting up a callback function, you have the option of specifying it with the creation of the notification (hs.notify.new) or by pre-registering it with hs.notify.register and then referring it to by the tag name specified with hs.notify.register. If you use this registration method for defining your callback functions, and make sure to register all expected callback functions within your init.lua file or files it includes, then callback functions will remain available for existing notifications in the User Notification Center even if Hammerspoon's configuration is reloaded or if Hammerspoon is restarted. If the callback tag is not present when the user acts on the notification, the Hammerspoon console will be raised as a default action.
---
--- A shorthand, based upon the original inspiration for this module from Hydra and Mjolnir, hs.notify.show, is provided if you just require a quick and simple informative notification without the bells and whistles.
---
--- This module is based in part on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

-- package.loadlib(
--     package.searchpath("hs._asm.extras.objectconversion",
--     package.cpath),"*")

local module   = require("hs.notify.internal")
local host     = require("hs.host")
local imagemod = require("hs.image")

-- private variables and methods -----------------------------------------

-- functions provide by the C library which should not be treated as attributes when
-- creating a new notification (see hs.notify.new below)
local protected_functions = {
  show = true,
  release = true,
  withdraw = true,
  __index = true,
  __gc = true,
}

local emptyFunctionPlaceholder = "__emptyFunctionPlaceHolder"

-- Public interface ------------------------------------------------------

module.activationTypes = ls.makeConstantsTable(module.activationTypes)

--- hs.notify.warnAboutMissingFunctionTag
--- Variable
--- A boolean value indicating whether or not a missing notification function tag should cause a warning to be printed to the console during activation callback. Defaults to true.

module.warnAboutMissingFunctionTag = true

--- hs.notify.new([fn,][attributes]) -> notification
--- Constructor
--- Creates a new notification object
---
--- Parameters:
---  * fn - An optional function or function-tag, which will be called when the user interacts with notifications. The notification object will be passed as an argument to the function. If you leave this parameter out or specify nil, then no callback will be attached to the notification.
---  * attributes - An optional table for applying attributes to the notification. Possible keys are:
---
---   * alwaysPresent   - see `hs.notify:alwaysPresent`
---   * autoWithdraw    - see `hs.notify:autoWithdraw`
---   * contentImage    - see `hs.notify:contentImage` (only supported in 10.9 and later)
---   * informativeText - see `hs.notify:informativeText`
---   * soundName       - see `hs.notify:soundName`
---   * subTitle        - see `hs.notify:subTitle`
---   * title           - see `hs.notify:title`
---
---  The following can also be set, but will only have an apparent effect on the notification when the user has set Hammerspoon's notification style to "Alert" in the Notification Center panel of System Preferences:
---
---   * actionButtonTitle - see `hs.notify:actionButtonTitle`
---   * hasActionButton   - see `hs.notify:hasActionButton`
---   * otherButtonTitle  - see `hs.notify:otherButtonTitle`
---
--- Returns:
---  * A notification object
---
--- Notes:
---  * A function-tag is a string key which corresponds to a function stored in the `hs.notify.registry` table with the `hs.notify.register()` function.
---  * If a notification does not have a `title` attribute set, OS X will not display it, so by default it will be set to "Notification". You can use the `title` key in the attributes table, or call `hs.notify:title()` before displaying the notification to change this.
module.new = function(fn, attributes)
  if type(fn) == "table" then
    attributes = fn
    fn = nil
  end
  fn = fn or emptyFunctionPlaceholder
  if fn == "" then fn = emptyFunctionPlaceholder end

  if type(fn) == "function" then
    local tmpTag = host.globallyUniqueString()
    module.register(tmpTag, fn)
    fn = tmpTag
  end

  attributes = attributes or { }
  if not attributes.title then attributes.title = "Notification" end

  local note = module._new(fn)
  for i,v in pairs(attributes) do
    if note[i] and not protected_functions[i] then
      note[i](note, v)
    end
  end
  return note
end

module._tag_handler = function(tag, notification)
  local found = false
  for k,v in pairs(module.registry) do
    if k ~= "n" and v ~= nil then
      if tag == tostring(tonumber(tag)) and tag == tostring(k) then tag = v[1] end
      if v[1] == tag then
        v[2](notification)
        found = true
        break
      end
    end
  end
  if not found and module.warnAboutMissingFunctionTag then print("-- hs.notify: function tag '"..tag.."' not found") end
end

--- hs.notify.show(title, subTitle, information[, tag]) -> notfication
--- Constructor
--- Shorthand constructor to create and show simple notifications
---
--- Parameters:
---  * title       - the title for the notification
---  * subTitle    - the subtitle, or second line, of the notification
---  * information - the main textual body of the notification
---  * tag         - a function tag corresponding to a function registered with `hs.notify.register`
---
--- Returns:
---  * a notification object
---
--- Notes:
---  * All three textual parameters are required, though they can be empty strings
---  * This function is really a shorthand for `hs.notify.new(...):send()`
module.show = function(title, subTitle, informativeText, tag)
  if not hs.fnutils.contains({"function", "string", "number", "nil"}, type(tag)) or
  (type(tag) == "number" and not module.registry[tag]) or
  (type(tag) == "string" and tag ~= "" and not tostring(module.registry):find("\n"..tag.."\n")) then
    error "tag must be a function or function-tag defined in hs.notify.registry"
    return nil
  end
  if type(title) ~= "string" or type(subTitle) ~= "string" or type(informativeText) ~= "string" then
    error("All three textual arguments to hs.notify.show must be present and must be strings.", 2)
    return nil
  else
    return module.new(tag, {
        title = title,
        subTitle = subTitle,
        informativeText = informativeText,
        autoWithdraw = true,
      }):send()
  end
end


--- hs.notify.register(tag, fn) -> id
--- Function
--- Registers a function callback with the specified tag for a notification. The callback function will be invoked when the user clicks on or interacts with a notification.
---
--- Parameters:
---  * tag - a string tag to identify the registered callback function. Use this as the function tag in `hs.notify.new` and `hs.notify.show`
---  * fn  - the function which should be invoked when a notification with this tag is interacted with.
---
--- Returns:
---  * a numerical id representing the entry in `hs.notify.registry` for this function. This number can be used with `hs.notify.unregister` to unregister a function later if you wish.
---
--- Notes:
---  * If a function is already registered with the specified tag, it is replaced by with the new one.
module.register = function(tag, fn)
  local found = false
  local id
  for k,v in pairs(module.registry) do
    if k ~= "n" and v ~= nil then
      if v[1] == tag then
        id = k
        v[2] = fn
        found = true
        break
      end
    end
  end
  if not found then
    id = module.registry.n + 1
    module.registry[id] = {tag, fn}
    module.registry.n = id
  end
  return id
end

--- hs.notify.unregister(id|tag)
--- Function
--- Unregisters a function callback so that it is no longer available as a callback when notifications corresponding to the specified entry are interacted with.
---
--- Parameters:
---  * id or tag - the numerical id provided by `hs.notify.register` or string tag representing the callback function to be removed
---
--- Returns:
---  * None
module.unregister = function(id)
  local found = false
  for i = 1, module.registry.n, 1 do
    if module.registry[i] then
      if type(module.registry[i][1]) == type(id) and module.registry[i][1] == id then
        found = i
        break
      end
    end
  end
  if not found then
    module.registry[id] = nil
  else
    module.registry[found] = nil
  end
end

--- hs.notify.unregisterall()
--- Function
--- Unregisters all functions registered as callbacks.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This does not remove the notifications from the User Notification Center, it just removes their callback function for when the user interacts with them. To remove all notifications, see `hs.notify.withdrawAll` and `hs.notify.withdrawAllScheduled`
module.unregisterall = function()

--- hs.notify.registry[]
--- Variable
--- A table containing the registered callback functions and their tags.
---
--- Notes:
---  * This table should not be modified directly. Use the `hs.notify.register(tag, fn)` and `hs.notify.unregister(id)` functions.
---  * This table has a __tostring metamethod so you can see the list of registered function tags in the console by typing `hs.notify.registry`
---  * If a notification attempts to perform a callback to a function tag which is not present in this table, a warning will be printed in the console.
module.registry = setmetatable({ { emptyFunctionPlaceholder, function(_) end } }, {
    __tostring = function(_)
      local result = ""
      for k,v in pairs(_) do
        if k ~= "n" and v ~= nil then result = result..v[1].."\n" end
      end
      return result
    end,
  })
module.registry.n = 1
end

--- hs.notify:contentImage([image]) -> notificationObject | current-setting
--- Method
--- Get or set a notification's content image.
---
--- Parameters:
---  * image - An optional hs.image parameter containing the image to display. Defaults to nil. If no parameter is provided, then the current setting is returned.
---
--- Returns:
---  * The notification object, if image is provided; otherwise the current setting.
---
--- Notes:
---  * See hs.image for details on how to specify or define an image
---  * This method is only supported in OS X 10.9 or greater. A warning will be displayed in the console and the method will be treated as a no-op if used on an unsupported system.
hs.getObjectMetatable("hs.notify").contentImage = function(...)
  local args = table.pack(...)
  local object = args[1]
  if args.n == 1 then
    return object:_contentImage()
  else
    local imagePath = args[2]
    local tmpImage = nil

    if type(imagePath) == "userdata" then
      tmpImage = imagePath
    elseif type(imagePath) == "string" then
      if string.sub(imagePath, 1, 6) == "ASCII:" then
        tmpImage = imagemod.imageFromASCII(string.sub(imagePath, 7, -1))
      else
        tmpImage = imagemod.imageFromPath(imagePath)
      end
    end

    return object:_contentImage(tmpImage)
  end
end

--- hs.notify:setIdImage(image[, withBorder]) -> notificationObject
--- Method
--- Set a notification's identification image (replace the Hammerspoon icon with a custom image)
---
--- Parameters:
---  * image - An `hs.image` object, a string containing an image path, or a string defining an ASCIImage
---  * withBorder - An optional boolean to give the notification image a border. Defaults to `false`
---
--- Returns:
---  * The notification object
---
--- Notes:
---  * See hs.image for details on how to specify or define an image
---  * **WARNING**: This method uses a private API. It could break at any time. Please file an issue if it does
hs.getObjectMetatable("hs.notify").setIdImage = function(self, imagePath, withBorder)
  withBorder = withBorder or false
  local tmpImage = nil

  if type(imagePath) == "userdata" then
    tmpImage = imagePath
  elseif type(imagePath) == "string" then
    if string.sub(imagePath, 1, 6) == "ASCII:" then
      tmpImage = imagemod.imageFromASCII(string.sub(imagePath, 7, -1))
    else
      tmpImage = imagemod.imageFromPath(imagePath)
    end
  end

  return self:_setIdImage(tmpImage, withBorder)
end

-- Return Module Object --------------------------------------------------

module.unregisterall() -- make sure placeholder is in effect and nothing else
return module
