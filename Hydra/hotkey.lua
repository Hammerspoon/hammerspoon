doc.hotkey.__doc = [[
Create and manage global hotkeys.

The `mods` field is case-insensitive and may any of the following strings: "cmd", "ctrl", "alt", or "shift".

The `key` field is case-insensitive and may be any single-character string; it may also be any of the following strings:

    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15, F16, F17, F18, F19, F20
    PAD, PAD*, PAD+, PAD/, PAD-, PAD=, PAD0, PAD1, PAD2, PAD3, PAD4, PAD5, PAD6, PAD7, PAD8, PAD9, PAD_CLEAR, PAD_ENTER
    RETURN, TAB, SPACE, DELETE, ESCAPE, HELP, HOME, PAGE_UP, FORWARD_DELETE, END, PAGE_DOWN, LEFT, RIGHT, DOWN, UP]]

hotkey.keys = {}
hotkey.keys.n = 0

doc.hotkey.new = {"hotkey.new(mods, key, fn) -> hotkey", "Creates a new hotkey that can be enabled. The hotkey has the public fields: key, mods, fn."}
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
