hotkey.keys = {}
hotkey.keys.n = 0

doc.hotkey.new = {"hotkey.new(mods, key, fn) -> hotkey", "Creates a new hotkey that can be enabled. Mods is a table containing any of the elements {cmd, ctrl, alt, shift}. Key may be any 1-character string, or 'F1', 'Enter', etc. Both are case-insensitive. The hotkey has the public fields: key, mods, fn."}
local hotkey_metatable = {__index = hotkey}
function hotkey.new(mods, key, fn)
  return setmetatable({mods = mods, key = key, fn = fn}, hotkey_metatable)
end

doc.hotkey.enable = {"hotkey:enable() -> self", "Registers the hotkey's fn as the callback when the user presses key while holding mods."}
function hotkey:enable()
  local uid = hotkey.keys.n + 1
  hotkey.keys.n = uid

  hotkey.keys[uid] = self
  self.__uid = uid

  return self:_enable()
end

doc.hotkey.disable = {"hotkey:disable() -> self", "Disables the given hotkey; does not remove it from hotkey.keys."}
function hotkey:disable()
  hotkey.keys[self.__uid] = nil
  self.__uid = nil

  return self:_disable()
end

doc.hotkey.bind = {"hotkey.bind(...) -> hotkey", "Shortcut for: return hotkey.new(...):enable()"}
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

doc.hotkey.disableall = {"hotkey.disableall()", "Disables all hotkeys; automatically called when user config reloads."}
function hotkey.disableall()
  for i, hotkey in pairs(hotkey.keys) do
    if hotkey and i ~= "n" then hotkey:disable() end
  end
  hotkey.keys.n = 0
end
