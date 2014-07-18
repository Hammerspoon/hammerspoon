--- === modalkey ===
---
--- For conveniently binding modal hotkeys.
---
--- This would be a simple example usage:
---
---     k = modalkey.new({"cmd", "shift"}, "d")
---
---     function k:entered() hydra.alert('Entered mode') end
---     function k:exited()  hydra.alert('Exited mode')  end
---
---     k:bind({}, 'escape', function() k:exit() end)
---     k:bind({}, 'J', function() hydra.alert("Pressed J") end)

modalkey = {}
modalkey.__index = modalkey

--- modalkey:entered()
--- Optional callback for when a modalkey is entered; default implementation does nothing.
function modalkey:entered()
end

--- modalkey:exited()
--- Optional callback for when a modalkey is exited; default implementation does nothing.
function modalkey:exited()
end

--- modalkey:bind(mods, key, pressedfn, releasedfn)
--- Registers a new hotkey that will be bound when the modalkey is enabled.
function modalkey:bind(mods, key, pressedfn, releasedfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn)
  table.insert(self.keys, k)
  return self
end

--- modalkey:enter()
--- Enables all hotkeys created via `modalkey:bind` and disables the modalkey itself.
--- Called automatically when the modalkey's hotkey is pressed.
function modalkey:enter()
  self.k:disable()
  fnutils.each(self.keys, hotkey.enable)
  self.entered()
  return self
end

--- modalkey:exit()
--- Disables all hotkeys created via `modalkey:bind` and re-enables the modalkey itself.
function modalkey:exit()
  fnutils.each(self.keys, hotkey.disable)
  self.k:enable()
  self.exited()
  return self
end

--- modalkey.new(mods, key) -> modalkey
--- Creates a new modal hotkey and enables it.
--- When mods and key are pressed, all keys bound via `modal:bind` will be enabled.
--- They are disabled when the "mode" is exited via `modalkey:exit()`
function modalkey.new(mods, key)
  local m = setmetatable({keys = {}}, modalkey)
  m.k = hotkey.bind(mods, key, function() m:enter() end)
  return m
end
