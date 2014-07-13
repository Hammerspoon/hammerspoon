--- hotkey
---
--- Create and manage global hotkeys.
---
--- The `mods` field is case-insensitive and may contain any of the following strings: "cmd", "ctrl", "alt", or "shift".
---
--- The `key` field is case-insensitive and may be any single-character string; it may also be any of the following strings:
---
---     F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15,
---     F16, F17, F18, F19, F20, PAD, PAD*, PAD+, PAD/, PAD-, PAD=,
---     PAD0, PAD1, PAD2, PAD3, PAD4, PAD5, PAD6, PAD7, PAD8, PAD9,
---     PAD_CLEAR, PAD_ENTER, RETURN, TAB, SPACE, DELETE, ESCAPE, HELP,
---     HOME, PAGE_UP, FORWARD_DELETE, END, PAGE_DOWN, LEFT, RIGHT, DOWN, UP

hotkey.keys = {}
hotkey.keys.n = 0

--- hotkey.keycodes
--- A mapping from string representation of a key to its keycode, and vice versa; not generally useful yet.
--- For example: keycodes[1] == "s", and keycodes["s"] == 1, and so on

for k, v in pairs(hotkey.keycodes) do
  hotkey.keycodes[v] = k
end

local function callback(uid)
  local k = hotkey.keys[uid]
  k.fn()
end

if not _timersetup then
  hotkey._setup(callback)
  _timersetup = true
end

--- hotkey.new(mods, key, fn) -> hotkey
--- Creates a new hotkey that can be enabled. The hotkey has the public fields: key, mods, fn.
local hotkey_metatable = {__index = hotkey}
function hotkey.new(mods, key, fn)
  return setmetatable({mods = mods, key = key, fn = fn}, hotkey_metatable)
end

--- hotkey:enable() -> self
--- Registers the hotkey's fn as the callback when the user presses key while holding mods.
function hotkey:enable()
  local uid = hotkey.keys.n + 1
  hotkey.keys.n = uid

  hotkey.keys[uid] = self
  self.__uid = uid

  local mods = {}
  for _, mod in pairs(self.mods) do
    mods[mod:lower()] = true
  end

  self.__carbonkey = hotkey._register(uid, hotkey.keycodes[self.key:lower()], mods.ctrl, mods.cmd, mods.alt, mods.shift, mods.caps)
  return self
end

--- hotkey:disable() -> self
--- Disables the given hotkey; does not remove it from hotkey.keys.
function hotkey:disable()
  hotkey._unregister(self.__carbonkey)

  hotkey.keys[self.__uid] = nil
  self.__uid = nil

  return self
end

--- hotkey.bind(mods, key, fn) -> hotkey
--- Shortcut for: return hotkey.new(mods, key, fn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

--- hotkey.disableall()
--- Disables all hotkeys; automatically called when user config reloads.
function hotkey.disableall()
  for i, hotkey in pairs(hotkey.keys) do
    if hotkey and i ~= "n" then hotkey:disable() end
  end
  hotkey.keys.n = 0
end
