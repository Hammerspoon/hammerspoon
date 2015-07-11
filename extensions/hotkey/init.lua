--- === hs.hotkey ===
---
--- Create and manage global keyboard shortcuts

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"
local fnutils = require "hs.fnutils"

--- hs.hotkey.new(mods, key, pressedfn[, releasedfn, repeatfn]) -> hs.hotkey
--- Constructor
--- Creates a new hotkey
---
--- Parameters:
---  * mods - A table containing the keyboard modifiers required, which should be zero or more of the following strings:
---   * cmd
---   * alt
---   * shift
---   * ctrl
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * pressedfn - A function that will be called when the hotkey has been pressed
---  * releasedfn - An optional function that will be called when the hotkey has been released
---  * repeatfn - An optional function that will be called when a pressed hotkey is repeating
---
--- Returns:
---  * A new `hs.hotkey` object, or nil if an error occurred
function hotkey.new(mods, key, pressedfn, releasedfn, repeatfn)
  local keycode

  if (key:sub(1, 1) == '#') then
    keycode = tonumber(key:sub(2))
  else
    keycode = keycodes.map[key:lower()]
  end

  if not keycode then
      print("Error: Invalid key: "..key)
      return nil
  end


  local k = hotkey._new(mods, keycode, pressedfn, releasedfn, repeatfn)
  return k
end

--- hs.hotkey.bind(mods, key, pressedfn, releasedfn, repeatfn, message, duration) -> hs.hotkey
--- Constructor
--- Creates a hotkey and enables it immediately
---
--- Parameters:
---  * mods - A table containing the keyboard modifiers required, which should be zero or more of the following strings:
---   * cmd
---   * alt
---   * shift
---   * ctrl
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * pressedfn - A function that will be called when the hotkey has been pressed
---  * releasedfn - (optional) A function that will be called when the hotkey has been released
---  * repeatfn - (optional) A function that will be called when a pressed hotkey is repeating
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been pressed
---  * duration - (optional) Duration of the alert message in seconds
---
--- Returns:
---  * A new `hs.hotkey` object or nil if an error occurred
---
--- Notes:
---  * This function is a wrapper that essentially performs: `hs.hotkey.new(mods, key, pressedfn, releasedfn, repeatfn):enable()`
---  * If you don't need `releasedfn` nor `repeatfn`, you can simply use `hs.hotkey.bind(mods,key,fn,"message")`
local alert,SYMBOLS,supper,ipairs,type = require'hs.alert',require'hs.utf8'.registeredKeys,string.upper,ipairs,type
--local SYMBOLS = {cmd='⌘',ctrl='⌃',alt='⌥',shift='⇧',hyper='✧'}
function hotkey.bind(mods, key, pressedfn, releasedfn, repeatfn, message, duration)
  if type(releasedfn)=='string' then duration=repeatfn message=releasedfn repeatfn=nil releasedfn=nil
  elseif type(repeatfn)=='string' then duration=message message=repeatfn repeatfn=nil end
  if type(message)~='string' then message=nil end
  if type(duration)~='number' then duration=nil end
  local fnalert
  if message then
    local s=''
    for _,mod in ipairs(mods) do s=s..SYMBOLS[mod] end
    if #mods>=4 then s=SYMBOLS.concaveDiamond end
    s=s..supper(key)
    if #message>0 then s=s..': '..message end
    fnalert=function()alert(s,duration or 1)pressedfn()end
  end
  local key=hotkey.new(mods,key,fnalert or pressedfn,releasedfn,repeatfn)
  return key and key:enable()
end

--- === hs.hotkey.modal ===
---
--- Create/manage modal keyboard shortcut environments
---
--- This would be a simple example usage:
---
---     k = hs.hotkey.modal.new({"cmd", "shift"}, "d")
---
---     function k:entered() hs.alert.show('Entered mode') end
---     function k:exited()  hs.alert.show('Exited mode')  end
---
---     k:bind({}, 'escape', function() k:exit() end)
---     k:bind({}, 'J', function() hs.alert.show("Pressed J") end)

hotkey.modal = {}
hotkey.modal.__index = hotkey.modal

--- hs.hotkey.modal:entered()
--- Method
--- Optional callback for when a modal is entered
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a pre-existing function that you should override if you need to use it
---  * The default implementation does nothing
function hotkey.modal:entered()
end

--- hs.hotkey.modal:exited()
--- Method
--- Optional callback for when a modal is exited
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a pre-existing function that you should override if you need to use it
---  * The default implementation does nothing
function hotkey.modal:exited()
end

--- hs.hotkey.modal:bind(mods, key, pressedfn, releasedfn, repeatfn) -> hs.hotkey.modal
--- Method
---
--- Parameters:
---  * mods - A table containing the keyboard modifiers required, which should be zero or more of the following strings:
---   * cmd
---   * alt
---   * shift
---   * ctrl
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * pressedfn - A function that will be called when the hotkey has been pressed
---  * releasedfn - An optional function that will be called when the hotkey has been released
---  * repeatfn - An optional function that will be called when a pressed hotkey is repeating
---
--- Returns:
---  * The `hs.hotkey.modal` object
---
function hotkey.modal:bind(mods, key, pressedfn, releasedfn, repeatfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn, repeatfn)
  table.insert(self.keys, k)
  return self
end

--- hs.hotkey.modal:enter() -> hs.hotkey.modal
--- Method
--- Enters a modal state
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey.modal` object
---
--- Notes:
---  * This method will enable all of the hotkeys defined in the modal state, and disable the hotkey that entered the modal state (if one was defined)
---  * If the modal state has a hotkey, this method will be called automatically
function hotkey.modal:enter()
  if (self.k) then
    self.k:disable()
  end
  fnutils.each(self.keys, hs.getObjectMetatable("hs.hotkey").enable)
  self:entered()
  return self
end

--- hs.hotkey.modal:exit() -> hs.hotkey.modal
--- Method
--- Exits a modal state
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey.modal` object
---
--- Notes:
---  * This method will disable all of the hotkeys defined in the modal state, and enable the hotkey for entering the modal state (if one was defined)
function hotkey.modal:exit()
  fnutils.each(self.keys, hs.getObjectMetatable("hs.hotkey").disable)
  if (self.k) then
    self.k:enable()
  end
  self:exited()
  return self
end

--- hs.hotkey.modal.new(mods, key) -> hs.hotkey.modal
--- Constructor
--- Creates a new modal state, optionally with a global hotkey to trigger it
---
--- Parameters:
---  * mods - A table containing keyboard modifiers for the optional global hotkey
---  * key - A string containing the name of a keyboard key (as found in `hs.keycodes.map`)
---
--- Returns:
---  * A new `hs.hotkey.modal` object
---
--- Notes:
---  * If `mods` and `key` are both nil, no global hotkey will be registered
function hotkey.modal.new(mods, key)
  if ((mods and not key) or (not mods and key)) then
    hs.showError("Incorrect use of hs.hotkey.modal.new(). Both parameters must either be valid, or nil. You cannot mix valid and nil parameters")
    return nil
  end
  local m = setmetatable({keys = {}}, hotkey.modal)
  if (mods and key) then
    m.k = hotkey.bind(mods, key, function() m:enter() end)
  end
  return m
end

return hotkey
