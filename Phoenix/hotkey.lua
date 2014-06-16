local util = require("util")

local hotkey = {}
local hotkey_metatable = {__index = hotkey}

hotkey.keys = {}

__api.hotkey_setup(function(uid)
    local k = hotkey.keys[uid]
    k.fn()
    return true -- TODO: allow the function itself to tell us what to return
end)

function hotkey.new(mods, key, fn)
  local k = {}
  k.mods = util.map(mods, string.lower)
  k.key = key
  k.fn = fn
  return setmetatable(k, hotkey_metatable)
end

-- convenience function
function hotkey.bind(...)
  local k = hotkey.new(...)
  return k:enable()
end

function hotkey:enable()
  self.__uid = #hotkey.keys + 1
  hotkey.keys[self.__uid] = self
  self.__carbonkey = __api.hotkey_register(util.contains(self.mods, "cmd"),
                                           util.contains(self.mods, "ctrl"),
                                           util.contains(self.mods, "alt"),
                                           util.contains(self.mods, "shift"),
                                           self.key,
                                           self.__uid)
  return self
end

function hotkey:disable()
  __api.hotkey_unregister(self.__carbonkey)
end

return hotkey
