--- === hs.hotkey ===
---
--- Create and manage global hotkeys.

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"

--- hs.hotkey.new(mods, key, pressedfn, releasedfn = nil) -> hotkey
--- Constructor
--- Creates a new hotkey that can be enabled.
---
--- The `mods` parameter is case-insensitive and may contain any of the following strings: "cmd", "ctrl", "alt", or "shift".
---
--- The `key` parameter is case-insensitive and may be any string value found in [hs.keycodes.map](hs.keycodes.html#map)
---
--- The `pressedfn` parameter is the function that will be called when this hotkey is pressed.
---
--- The `releasedfn` parameter is the function that will be called when this hotkey is released; this field is optional (i.e. may be nil or omitted).

local function wrap(fn)
  return function()
    if fn then
      local ok, err = xpcall(fn, debug.traceback)
      if not ok then hs.showerror(err) end
    end
  end
end

function hotkey.new(mods, key, pressedfn, releasedfn)
  local keycode = keycodes.map[key:lower()]

  if not keycode then
      print("Error: Invalid key: "..key)
      return nil
  end

  local _pressedfn = wrap(pressedfn)
  local _releasedfn = wrap(releasedfn)

  local k = hotkey._new(mods, keycode, _pressedfn, _releasedfn)
  return k
end

--- hs.hotkey.bind(mods, key, pressedfn, releasedfn) -> hotkey
--- Constructor
--- Shortcut for: return hs.hotkey.new(mods, key, pressedfn, releasedfn):enable()
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
--- For conveniently binding modal hotkeys.
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
--- Optional callback for when a modal is entered; default implementation does nothing.
function hotkey.modal:entered()
end

--- hs.hotkey.modal:exited()
--- Optional callback for when a modal is exited; default implementation does nothing.
function hotkey.modal:exited()
end

--- hs.hotkey.modal:bind(mods, key, pressedfn, releasedfn)
--- Registers a new hotkey that will be bound when the modal is enabled.
function hotkey.modal:bind(mods, key, pressedfn, releasedfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn)
  table.insert(self.keys, k)
  return self
end

--- hs.hotkey.modal:enter()
--- Enables all hotkeys created via `modal:bind` and disables the modal itself.
--- Called automatically when the modal's hotkey is pressed.
function hotkey.modal:enter()
  self.k:disable()
  hs.fnutils.each(self.keys, hotkey.enable)
  self.entered()
  return self
end

--- hs.hotkey.modal:exit()
--- Disables all hotkeys created via `modal:bind` and re-enables the modal itself.
function hotkey.modal:exit()
  hs.fnutils.each(self.keys, hotkey.disable)
  self.k:enable()
  self.exited()
  return self
end

--- hs.hotkey.modal.new(mods, key) -> modal
--- Creates a new modal hotkey and enables it.
--- When mods and key are pressed, all keys bound via `modal:bind` will be enabled.
--- They are disabled when the "mode" is exited via `modal:exit()`
function hotkey.modal.new(mods, key)
  local m = setmetatable({keys = {}}, hotkey.modal)
  m.k = hotkey.bind(mods, key, function() m:enter() end)
  return m
end

return hotkey
