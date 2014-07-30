--- === hotkey.modal ===
---
--- For conveniently binding modal hotkeys.
---
--- This would be a simple example usage:
---
---     k = hotkey.modal.new({"cmd", "shift"}, "d")
---
---     function k:entered() hydra.alert('Entered mode') end
---     function k:exited()  hydra.alert('Exited mode')  end
---
---     k:bind({}, 'escape', function() k:exit() end)
---     k:bind({}, 'J', function() hydra.alert("Pressed J") end)

hotkey.modal = {}
hotkey.modal.__index = hotkey.modal

--- hotkey.modal:entered()
--- Optional callback for when a modal is entered; default implementation does nothing.
function hotkey.modal:entered()
end

--- hotkey.modal:exited()
--- Optional callback for when a modal is exited; default implementation does nothing.
function hotkey.modal:exited()
end

--- hotkey.modal:bind(mods, key, pressedfn, releasedfn)
--- Registers a new hotkey that will be bound when the modal is enabled.
function hotkey.modal:bind(mods, key, pressedfn, releasedfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn)
  table.insert(self.keys, k)
  return self
end

--- hotkey.modal:enter()
--- Enables all hotkeys created via `modal:bind` and disables the modal itself.
--- Called automatically when the modal's hotkey is pressed.
function hotkey.modal:enter()
  self.k:disable()
  fnutils.each(self.keys, hotkey.enable)
  self.entered()
  return self
end

--- hotkey.modal:exit()
--- Disables all hotkeys created via `modal:bind` and re-enables the modal itself.
function hotkey.modal:exit()
  fnutils.each(self.keys, hotkey.disable)
  self.k:enable()
  self.exited()
  return self
end

--- hotkey.modal.new(mods, key) -> modal
--- Creates a new modal hotkey and enables it.
--- When mods and key are pressed, all keys bound via `modal:bind` will be enabled.
--- They are disabled when the "mode" is exited via `modal:exit()`
function hotkey.modal.new(mods, key)
  local m = setmetatable({keys = {}}, hotkey.modal)
  m.k = hotkey.bind(mods, key, function() m:enter() end)
  return m
end
