--- === hs.hotkey ===
---
--- Create and manage global keyboard shortcuts

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"

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
--- Optional callback for when a modal is entered; default implementation does nothing.
function hotkey.modal:entered()
end

--- hs.hotkey.modal:exited()
--- Method
--- Optional callback for when a modal is exited; default implementation does nothing.
function hotkey.modal:exited()
end

--- hs.hotkey.modal:bind(mods, key, pressedfn, releasedfn)
--- Method
--- Registers a new hotkey that will be bound when the modal is enabled.
function hotkey.modal:bind(mods, key, pressedfn, releasedfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn)
  table.insert(self.keys, k)
  return self
end

--- hs.hotkey.modal:enter()
--- Method
--- Enables all hotkeys created via `modal:bind` and disables the modal itself.
--- Called automatically when the modal's hotkey is pressed.
function hotkey.modal:enter()
  if (self.k) then
    self.k:disable()
  end
  hs.fnutils.each(self.keys, hotkey.enable)
  self.entered()
  return self
end

--- hs.hotkey.modal:exit()
--- Method
--- Disables all hotkeys created via `modal:bind` and re-enables the modal itself.
function hotkey.modal:exit()
  hs.fnutils.each(self.keys, hotkey.disable)
  if (self.k) then
    self.k:enable()
  end
  self.exited()
  return self
end

--- hs.hotkey.modal.new(mods, key) -> modal
--- Constructor
--- Creates a new modal hotkey and enables it.
--- When mods and key are pressed, all keys bound via `modal:bind` will be enabled.
--- They are disabled when the "mode" is exited via `modal:exit()`
--- If mods and key are both nil, the modal state will be created with no top-level hotkey to enter the modal state. This is useful where you want a modal state to exist, but be entered programatically.
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
