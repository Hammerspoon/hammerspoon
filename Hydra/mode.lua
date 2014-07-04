-- mode.lua v2014.07.04

ext.mode = {}


local function _enter()
   hydra.alert('ENTERED MODE')
end

local function _exit()
   hydra.alert('EXITED MODE')
end

local mode = {_uid = 1, _enter = _enter, _exit = _exit}

function mode:bind(mods, key, fn)
   self[self._uid] = hotkey.new(mods, key, fn)
   self._uid = self._uid + 1
   return self
end

function mode:disable()
   self.hk:disable()
   return self
end

function mode:enable()
   self.hk:enable()
   return self
end

function mode:enter()
   self._enter()
   self:disable()
   for n=1,(self._uid-1) do
      self[n]:enable()
   end
   return self
end

function mode:exit()
   for n=1,(self._uid-1) do
      self[n]:disable()
   end
   self._exit()
   self:enable()
   return self
end


-------------------------------------------
---------------- mode API -----------------
-------------------------------------------
local mode_metatable = {__index = mode}

function ext.mode.bind(mods, key, enter, exit)
   local mode = {_exit = exit, _enter = enter}
   mode = setmetatable(mode, mode_metatable)
   mode.hk = hotkey.bind(mods, key, function() mode.enter(mode) end)
   return mode
end
