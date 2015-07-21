--- === hs.hotkey ===
---
--- Create and manage global keyboard shortcuts

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"
local fnutils = require "hs.fnutils"
local alert = require'hs.alert'
local tonumber,pairs,ipairs,type,tremove,tinsert,tconcat = tonumber,pairs,ipairs,type,table.remove,table.insert,table.concat
local supper,slower,sfind=string.upper,string.lower,string.find

local function getKeycode(s)
  if (s:sub(1, 1) == '#') then return tonumber(s:sub(2))
  else return keycodes.map[s:lower()] end
end

local hotkeys,hkmap = {},{}

--- hs.hotkey:enable() -> hs.hotkey
--- Method
--- Enables a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey` object

local function enable(self,force)
  if not force and self.enabled then return self end --this ensures "nested shadowing" behaviour
  local idx = hkmap[self]
  if not idx or not hotkey[idx] then error('Internal error!') end
  local i = fnutils.indexOf(hotkey[idx],self)
  if not i then error('Internal error!') end
  tremove(hotkey[idx],i)
  for _,hk in ipairs(hotkey[idx]) do hk._hk:disable() end
  self.enabled = true
  self._hk:enable() --objc
  tinsert(hotkey[idx],self) -- bring to end
  return self
end

--- hs.hotkey:disable() -> hs.hotkey
--- Method
--- Disables a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey` object
local function disable(self)
  if not self.enabled then return self end
  local idx = hkmap[self]
  if not idx or not hotkey[idx] then error('Internal error!') end
  self.enabled = nil
  self._hk:disable() --objc
  for i=#hotkey[idx],1,-1 do
    if hotkey[idx][i].enabled then hotkey[idx][i]._hk:enable() break end
  end
  return self
end
--- hs.hotkey:delete() -> hs.hotkey
--- Method
--- Disables and deletes a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey` object

local function delete(self)
  disable(self)
  local idx=hkmap[self]
  if not idx or not hotkey[idx] then error('Internal error!') end
  for i=#hotkey[idx],1,-1 do
    if hotkey[idx][i]==self then tremove(hotkey[idx],i) break end
  end
  hkmap[self]=nil
  for k in pairs(self) do self[k]=nil end --gc
end

local function getMods(mods)
  local r={}
  if not mods then return r end
  if type(mods)=='table' then mods=tconcat(mods,'-') end
  if type(mods)~='string' then error('mods must be a string or a table of strings',3) end
  mods=slower(mods)
  local function find(ps)
    for _,s in ipairs(ps) do
      if sfind(mods,s,1,true) then r[#r+1]=ps[#ps] return end
    end
  end
  find{'cmd','command','⌘'} find{'ctrl','control','⌃'}
  find{'alt','option','⌥'} find{'shift','⇧'}
  return r
end
--- hs.hotkey.new(mods, key, pressedfn, releasedfn, repeatfn, message, duration) -> hs.hotkey
--- Constructor
--- Creates a new hotkey
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---   * "cmd", "command" or "⌘"
---   * "ctrl", "control" or "⌃"
---   * "alt", "option" or "⌥"
---   * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * pressedfn - (optional) A function that will be called when the hotkey has been pressed
---  * releasedfn - (optional) A function that will be called when the hotkey has been released
---  * repeatfn - (optional) A function that will be called when a pressed hotkey is repeating
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered
---  * duration - (optional) Duration of the alert message in seconds
---
--- Returns:
---  * A new `hs.hotkey` object
---
--- Notes:
---  * If you don't need `releasedfn` nor `repeatfn`, you can simply use `hs.hotkey.new(mods,key,fn,"message")`
---  * You can create multiple `hs.hotkey` objects for the same hotkey, but only one can be active at any given time

--local SYMBOLS = {cmd='⌘',ctrl='⌃',alt='⌥',shift='⇧',hyper='✧'}
local CONCAVE_DIAMOND='✧'
function hotkey.new(mods, key, pressedfn, releasedfn, repeatfn, message, duration)
  if type(key)~='string' then error('key must be a string',2) end
  local keycode = getKeycode(key) or error("Invalid key: "..key,2)
  mods = getMods(mods)
  if type(pressedfn)~='function' and type(releasedfn)~='function' and type(repeatfn)~='function' then
    error('At least one of pressedfn, releasedfn or repeatfn must be a function',2) end
  if type(releasedfn)=='string' then duration=repeatfn message=releasedfn repeatfn=nil releasedfn=nil
  elseif type(repeatfn)=='string' then duration=message message=repeatfn repeatfn=nil end
  if type(message)~='string' then message=nil end
  if type(duration)~='number' then duration=nil end
  local modstr = tconcat(mods)
  if #mods>=4 then modstr=CONCAVE_DIAMOND end
  local desc=modstr..supper(key)
  if message then
    if #message>0 then desc=desc..': '..message end
    local actualfn=pressedfn or releasedfn or repeatfn
    local fnalert=function()alert(desc,duration or 1)actualfn()end
    if pressedfn then pressedfn=fnalert
    elseif releasedfn then releasedfn=fnalert
    elseif repeatfn then repeatfn=fnalert end
  end
  local idx = modstr..keycode
  local hk = {_hk=hotkey._new(mods, keycode, pressedfn, releasedfn, repeatfn),enable=enable,disable=disable,delete=delete,desc=desc}
  hkmap[hk] = idx
  local h = hotkey[idx] or {}
  h[#h+1] = hk
  hotkey[idx] = h
  return hk
end

--- hs.hotkey.disableAll(mods, key)
--- Function
--- Disables all previously set callbacks for a given hotkey
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---   * "cmd", "command" or "⌘"
---   * "ctrl", "control" or "⌃"
---   * "alt", "option" or "⌥"
---   * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---
--- Returns:
---  * None
function hotkey.disableAll(mods,key)
  if type(key)~='string' then error('key must be a string',2) end
  local keycode = getKeycode(key) or error("Invalid key: "..key,2)
  local idx=tconcat(getMods(mods))..keycode
  for _,hk in ipairs(hotkey[idx] or {}) do
    hk:disable()
    --    hk._hk:disable() --objc
    --    hkmap[hk]=nil
  end
  --  hotkey[idx]=nil
end

function hotkey.deleteAll(mods,key)
  if type(key)~='string' then error('key must be a string',2) end
  local keycode = getKeycode(key) or error("Invalid key: "..key,2)
  local idx=tconcat(getMods(mods))..keycode
  for _,hk in ipairs(hotkey[idx] or {}) do
    hk._hk:disable() --objc
    hkmap[hk]=nil
  end
  hotkey[idx]=nil
end

--- hs.hotkey.bind(mods, key, pressedfn, releasedfn, repeatfn, message, duration) -> hs.hotkey
--- Constructor
--- Creates a hotkey and enables it immediately
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---   * "cmd", "command" or "⌘"
---   * "ctrl", "control" or "⌃"
---   * "alt", "option" or "⌥"
---   * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * pressedfn - (optional) A function that will be called when the hotkey has been pressed
---  * releasedfn - (optional) A function that will be called when the hotkey has been released
---  * repeatfn - (optional) A function that will be called when a pressed hotkey is repeating
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered
---  * duration - (optional) Duration of the alert message in seconds
---
--- Returns:
---  * A new `hs.hotkey` object
---
--- Notes:
---  * This function is just a wrapper that performs `hs.hotkey.new(...):enable()`
function hotkey.bind(...)
  return hotkey.new(...):enable()
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

--- hs.hotkey.modal:bind(mods, key, pressedfn, releasedfn, repeatfn) -> hs.hotkey.modal
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
---  * The `hs.hotkey.modal` object
---
function hotkey.modal:bind(mods, key, pressedfn, releasedfn, repeatfn)
  local k = hotkey.new(mods, key, pressedfn, releasedfn, repeatfn)
  tinsert(self.keys, k._hk)
  return self
end

--- hs.hotkey.modal:enter() -> hs.hotkey.modal
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
  fnutils.each(self.keys, hs.getObjectMetatable("hs.hotkey").enable)
  self:entered()
  return self
end

--- hs.hotkey.modal:exit() -> hs.hotkey.modal
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
  fnutils.each(self.keys, hs.getObjectMetatable("hs.hotkey").disable)
  if (self.k) then
    self.k:enable()
  end
  self:exited()
  return self
end

--- hs.hotkey.modal.new(mods, key) -> hs.hotkey.modal
--- Constructor
--- Creates a new modal state, optionally with a global hotkey to trigger it
---
--- Parameters:
---  * mods - A table containing keyboard modifiers for the optional global hotkey
---  * key - A string containing the name of a keyboard key (as found in `hs.keycodes.map`)
---
--- Returns:
---  * A new `hs.hotkey.modal` object
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
