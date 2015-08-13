--- === hs.hotkey ===
---
--- Create and manage global keyboard shortcuts

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"
local fnutils = require "hs.fnutils"
local alert = require'hs.alert'
local log = require'hs.logger'.new('hotkey','info')
hotkey.setLogLevel=log.setLogLevel

local tonumber,pairs,ipairs,type,tremove,tinsert,tconcat = tonumber,pairs,ipairs,type,table.remove,table.insert,table.concat
local supper,slower,sfind=string.upper,string.lower,string.find

local function error(err,lvl) return hs.showError(err,lvl+1,true) end

local function getKeycode(s)
  if type(s)~='string' then error('key must be a string',3) end
  local n
  if (s:sub(1, 1) == '#') then n=tonumber(s:sub(2))
  else n=keycodes.map[slower(s)] end
  if not n then error('Invalid key: '..s,3) end
  return n
end

local hotkeys = {}

--- hs.hotkey.alertDuration
--- Variable
--- Duration of the alert shown when a hotkey created with a `message` parameter is triggered, in seconds. Default is 1.
---
--- Usage:
--- hs.hotkey.alertDuration = 2.5 -- alert stays on screen a bit longer
--- hs.hotkey.alertDuration = 0 -- hotkey alerts are disabled
hotkey.alertDuration = 1

--- hs.hotkey:enable() -> hs.hotkey object
--- Method
--- Enables a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey` object for method chaining
---
--- Notes:
---  * When you enable a hotkey that uses the same keyboard combination as another previously-enabled hotkey, the old
---    one will stop working as it's being "shadowed" by the new one. As soon as the new hotkey is disabled or deleted
---    the old one will trigger again.
local function enable(self,force,isModal)
  if not force and self.enabled then log.v('Hotkey already enabled') return self end --this ensures "nested shadowing" behaviour
  local idx = self.idx
  if not idx or not hotkeys[idx] then log.e('The hotkey was deleted, cannot enable it') return end
  local i = fnutils.indexOf(hotkeys[idx],self)
  if i then tremove(hotkeys[idx],i) end
  for _,hk in ipairs(hotkeys[idx]) do
    if hk.enabled then log.i('Disabled previous hotkey '..hk.msg) end
    hk._hk:disable()
  end
  self.enabled = true
  self._hk:enable() --objc
  log[isModal and 'df' or 'f']('Enabled hotkey %s%s',self.msg,isModal and ' (in modal)' or '')
  tinsert(hotkeys[idx],self) -- bring to end
  return self
end

--- hs.hotkey:disable() -> hs.hotkey object
--- Method
--- Disables a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey` object for method chaining
local function disable(self,isModal)
  if not self.enabled then return self end
  local idx = self.idx
  if not idx or not hotkeys[idx] then log.w('The hotkey was deleted, cannot disable it') return end
  self.enabled = nil
  self._hk:disable() --objc
  log[isModal and 'df' or 'f']('Disabled hotkey %s%s',self.msg,isModal and ' (in modal)' or '')
  for i=#hotkeys[idx],1,-1 do
    if hotkeys[idx][i].enabled then
      log.i('Re-enabled previous hotkey '..hotkeys[idx][i].msg)
      hotkeys[idx][i]._hk:enable()
      break
    end
  end
  return self
end

--- hs.hotkey:delete()
--- Method
--- Disables and deletes a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
local function delete(self)
  local idx=self.idx
  if not idx or not hotkeys[idx] then log.w('The hotkey has already been deleted') return end --?
  disable(self)
  local i = fnutils.indexOf(hotkeys[idx],self)
  if i then tremove(hotkeys[idx],i) end
  for k in pairs(self) do self[k]=nil end --gc
  log.i('Deleted hotkey '..self.msg)
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

--local SYMBOLS = {cmd='⌘',ctrl='⌃',alt='⌥',shift='⇧',hyper='✧'}
local CONCAVE_DIAMOND='✧'
local function getIndex(mods,keycode)
  local mods = getMods(mods)
  mods = #mods>=4 and CONCAVE_DIAMOND or tconcat(mods)
  local key=keycodes.map[keycode]
  key=key and supper(key) or keycode
  return mods..key
end
--- hs.hotkey.new(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> hs.hotkey object
--- Constructor
--- Creates a new hotkey
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been
---    triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * A new `hs.hotkey` object
---
--- Notes:
---  * You can create multiple `hs.hotkey` objects for the same keyboard combination, but only one can be active
---    at any given time - see `hs.hotkey:enable()`
---  * If `message` is the empty string `""`, the alert will just show the triggered keyboard combination
---  * If you don't want any alert, you must *actually* omit the `message` parameter; a `nil` in 3rd position
---    will be interpreted as a missing `pressedfn`
---  * You must pass at least one of `pressedfn`, `releasedfn` or `repeatfn`; to delete a hotkey, use `hs.hotkey:delete()`

function hotkey.new(mods, key, message, pressedfn, releasedfn, repeatfn)
  local keycode = getKeycode(key)
  mods = getMods(mods)
  -- message can be optional
  if message==nil or type(message)=='function' then
    repeatfn=releasedfn releasedfn=pressedfn pressedfn=message message=nil
  end
  if type(pressedfn)~='function' and type(releasedfn)~='function' and type(repeatfn)~='function' then
    error('At least one of pressedfn, releasedfn or repeatfn must be a function',2) end
  if type(message)~='string' then message=nil end
  local idx = getIndex(mods,keycode)
  local msg=(message and #message>0) and idx..': '..message or idx
  if message then
    local actualfn=pressedfn or releasedfn or repeatfn
    local fnalert=function()alert(msg,hotkey.alertDuration or 0)actualfn()end
    if pressedfn then pressedfn=fnalert
    elseif releasedfn then releasedfn=fnalert
    elseif repeatfn then repeatfn=fnalert end
  end
  local hk = {_hk=hotkey._new(mods, keycode, pressedfn, releasedfn, repeatfn),enable=enable,disable=disable,delete=delete,msg=msg,idx=idx}
  log.v('Created hotkey for '..idx)
  local h = hotkeys[idx] or {}
  h[#h+1] = hk
  hotkeys[idx] = h
  return hk
end

--- hs.hotkey.disableAll(mods, key)
--- Function
--- Disables all previously set callbacks for a given keyboard combination
---
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---
--- Returns:
---  * None
function hotkey.disableAll(mods,key)
  local idx=getIndex(mods,getKeycode(key))
  for _,hk in ipairs(hotkeys[idx] or {}) do hk:disable() end
end

--- hs.hotkey.deleteAll(mods, key)
--- Function
--- Deletes all previously set callbacks for a given keyboard combination
---
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---
--- Returns:
---  * None
function hotkey.deleteAll(mods,key)
  local idx=getIndex(mods,getKeycode(key))
  local t=hotkeys[idx] or {}
  for i=#t,1,-1 do t[i]:delete() end
  hotkeys[idx]=nil
end

--- hs.hotkey.getHotkeys() -> table
--- Function
--- Returns a list of all currently active hotkeys
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing the hotkeys that are active, i.e. enabled and not "shadowed", in the current context
---    (usually, the global hotkey context, but it could be a modal hotkey context). Every element in the list
---    is a table with two fields:
---    * idx - a string describing the keyboard combination for the hotkey
---    * msg - the hotkey message, if provided when the hotkey was created (prefixed with the keyboard combination)

--- hs.hotkey.showHotkeys(mods, key) -> hs.hotkey object
--- Function
--- Creates (and enables) a hotkey that shows all currently active hotkeys (i.e. enabled and not "shadowed"
--- in the current context) while pressed
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---
--- Returns:
---  * The new `hs.hotkey` object

local helpHotkey
function hotkey.getHotkeys()
  local t={}
  for idx,hks in pairs(hotkeys) do
    for i=#hks,1,-1 do
      if hks[i].enabled and hks[i]~=helpHotkey then
        t[#t+1] = hks[i]
        break
      end
    end
  end
  table.sort(t,function(a,b)if#a.idx==#b.idx then return a.idx<b.idx else return #a.idx<#b.idx end end)
  if helpHotkey then tinsert(t,1,helpHotkey) end
  return t
end

local function showHelp()
  local t=hotkey.getHotkeys()
  --  hs.alert(helpHotkey.msg,3600)
  local s=''
  for i=2,#t do s=s..t[i].msg..'\n' end
  hs.alert(string.sub(s,1,-2),3600)
end
function hotkey.showHotkeys(mods,key)
  if helpHotkey then delete(helpHotkey) end
  helpHotkey = hotkey.bind(mods,key,'Show active hotkeys',showHelp,hs.alert.closeAll)
  return helpHotkey
end
--- hs.hotkey.bind(mods, key, message, pressedfn, releasedfn, repeatfn) -> hs.hotkey object
--- Constructor
--- Creates a hotkey and enables it immediately
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * message - A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered, or nil for no alert
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * A new `hs.hotkey` object for method chaining
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
--- Usage:
--- k = hs.hotkey.modal.new('cmd-shift', 'd')
--- function k:entered() hs.alert'Entered mode' end
--- function k:exited()  hs.alert'Exited mode'  end
--- k:bind('', 'escape', function() k:exit() end)
--- k:bind('', 'J', 'Pressed J',function() print'let the record show that J was pressed' end)

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
---  * This is a pre-existing function that you should override if you need to use it; the default implementation does nothing.
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
---  * This is a pre-existing function that you should override if you need to use it; the default implementation does nothing.
function hotkey.modal:exited()
end

--- hs.hotkey.modal:bind(mods, key, message, pressedfn, releasedfn, repeatfn) -> hs.hotkey.modal object
--- Method
--- Creates a hotkey that is enabled/disabled as the modal is entered/exited
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * message - A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered, or nil for no alert
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * The `hs.hotkey.modal` object for method chaining
function hotkey.modal:bind(...)
  tinsert(self.keys, hotkey.new(...))
  return self
end

--- hs.hotkey.modal:enter() -> hs.hotkey.modal object
--- Method
--- Enters a modal state
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey.modal` object for method chaining
---
--- Notes:
---  * This method will enable all of the hotkeys defined in the modal state via `hs.hotkey.modal:bind()`,
---    and disable the hotkey that entered the modal state (if one was defined)
---  * If the modal state was created with a keyboard combination, this method will be called automatically
function hotkey.modal:enter()
  log.d('Entering modal')
  if (self.k) then
    disable(self.k)
  end
  for _,hk in ipairs(self.keys) do enable(hk,nil,true) end
  self:entered()
  return self
end

--- hs.hotkey.modal:exit() -> hs.hotkey.modal object
--- Method
--- Exits a modal state
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey.modal` object for method chaining
---
--- Notes:
---  * This method will disable all of the hotkeys defined in the modal state, and enable the hotkey for entering the modal state (if one was defined)
function hotkey.modal:exit()
  for _,hk in ipairs(self.keys) do disable(hk,true) end
  if (self.k) then
    enable(self.k)
  end
  self:exited()
  log.d('Exited modal')
  return self
end

--- hs.hotkey.modal.new(mods, key, message) -> hs.hotkey.modal object
--- Constructor
--- Creates a new modal state, optionally with a global keyboard combination to trigger it
---
--- Parameters:
---  * mods - A string containing (as substrings, with any separator) the keyboard modifiers required, which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or
---    if the string begins with a `#` symbol, the remainder of the string will be treated as a raw keycode number
---  * message - A string containing a message to be displayed via `hs.alert()` when the hotkey has been triggered, or nil for no alert
---
--- Returns:
---  * A new `hs.hotkey.modal` object
---
--- Notes:
---  * If `key` is nil, no global hotkey will be registered (all other parameters will be ignored)
function hotkey.modal.new(mods, key, message)
  local m = setmetatable({keys = {}}, hotkey.modal)
  if (key) then
    m.k = hotkey.bind(mods, key, message, function() m:enter() end)
  end
  log.d('Created modal hotkey')
  return m
end

return hotkey
