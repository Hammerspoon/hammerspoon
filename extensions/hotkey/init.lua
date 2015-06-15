--- === hs.hotkey ===
---
--- Create and manage global keyboard shortcuts

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"
local fnutils = require "hs.fnutils"

--- hs.hotkey.new(mods, key, pressedfn[, releasedfn, repeatfn]) -> hotkeyObject or nil
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
---  * An `hs.hotkey` object, or nil if an error occurred

local function wrap(fn)
  return function()
    if fn then
      local ok, err = xpcall(fn, debug.traceback)
      if not ok then hs.showError(err) end
    end
  end
end

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

  local _pressedfn = wrap(pressedfn)
  local _releasedfn = wrap(releasedfn)
  local _repeatfn = wrap(repeatfn)

  local k = hotkey._new(mods, keycode, _pressedfn, _releasedfn, _repeatfn)
  return k
end

--- hs.hotkey.bind(mods, key, pressedfn, releasedfn, repeatfn) -> hotkeyObject or nil
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
---  * releasedfn - An optional function that will be called when the hotkey has been released
---  * repeatfn - An optional function that will be called when a pressed hotkey is repeating
---
--- Returns:
---  * An `hs.hotkey` object or nil if an error occurred
---
--- Notes:
---  * This function is a simple wrapper that performs: `hs.hotkey.new(mods, key, pressedfn, releasedfn, repeatfn):enable()`
function hotkey.bind(...)
  local key = hotkey.new(...)
  if key then
      return key:enable()
  else
      return nil
  end
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

--- hs.hotkey.modal:bind(mods, key, pressedfn, releasedfn, repeatfn)
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
---  * An `hs.hotkey.modal` object or nil if an error occurred
---
function hotkey.modal:bind(mods, key, pressedfn, releasedfn, repeatfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn, repeatfn)
  table.insert(self.keys, k)
  return self
end

--- hs.hotkey.modal:enter()
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
  fnutils.each(self.keys, hotkey.enable)
  self.entered()
  return self
end

--- hs.hotkey.modal:exit()
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
  fnutils.each(self.keys, hotkey.disable)
  if (self.k) then
    self.k:enable()
  end
  self.exited()
  return self
end

--- hs.hotkey.modal.new(mods, key) -> modal
--- Constructor
--- Creates a new modal state, optionally with a global hotkey to trigger it
---
--- Parameters:
---  * mods - A table containing keyboard modifiers for the optional global hotkey
---  * key - A string containing the name of a keyboard key (as found in `hs.keycodes.map`)
---
--- Returns:
---  * An `hs.hotkey.modal` object
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
