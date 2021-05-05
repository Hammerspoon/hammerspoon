--- === hs.hotkey ===
---
--- Create and manage global keyboard shortcuts

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"
local alert = require'hs.alert'
local log = require'hs.logger'.new('hotkey','info')
hotkey.setLogLevel=log.setLogLevel
hotkey.getLogLevel=log.getLogLevel

local tonumber,pairs,ipairs,type,tremove,tinsert,tconcat,tsort = tonumber,pairs,ipairs,type,table.remove,table.insert,table.concat,table.sort
local supper,slower,sfind=string.upper,string.lower,string.find

--local function error(err,lvl) return hs.showError(err,(lvl or 1)+1,true) end -- this should go away, #477

local function getKeycode(s)
  local n
  if type(s)=='number' then n=s
  elseif type(s)~='string' then error('key must be a string or a number',3)
  elseif (s:sub(1, 1) == '#') then n=tonumber(s:sub(2))
  else n=keycodes.map[slower(s)] end
  if not n then error('Invalid key: '..s..' - this may mean that the key requested does not exist in your keymap (particularly if you switch keyboard layouts frequently)',3) end
  return n
end

-- all enabled hotkeys go here; every key is a keyboard combination (string), associated value is a stack (list) of lightweight
-- hotkey objects, created in new(); the currently enabled hotkey sits at the top of the stack
local hotkeys = {}

--- hs.hotkey.alertDuration
--- Variable
--- Duration of the alert shown when a hotkey created with a `message` parameter is triggered, in seconds. Default is 1.
---
--- Usage:
--- hs.hotkey.alertDuration = 2.5 -- alert stays on screen a bit longer
--- hs.hotkey.alertDuration = 0 -- hotkey alerts are disabled
hotkey.alertDuration = 1

--- hs.hotkey:enable() -> hs.hotkey object | nil
--- Method
--- Enables a hotkey object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.hotkey` object for method chaining or nil if the hotkey could not be enabled for some reason.
---
--- Notes:
---  * When you enable a hotkey that uses the same keyboard combination as another previously-enabled hotkey, the old
---    one will stop working as it's being "shadowed" by the new one. As soon as the new hotkey is disabled or deleted
---    the old one will trigger again.
local function enable(self,force,isModal)
  -- force is there just in case it'll be needed down the line; not exposed as public API for now
  -- isModal is only used to differentiate loglevel (modals can cause a lot of shadowing/unshadowing)

  -- this ensures "nested shadowing" behaviour; i.e. can't re-enable a hotkey that is currently shadowed (unless force),
  -- must wait for the current top dog to get disabled
  if not force and self.enabled then log.v('Hotkey already enabled') return self end
  local idx = self.idx
  if not idx or not hotkeys[idx] then log.e('The hotkey was deleted, cannot enable it') return end
  for i=#hotkeys[idx],1,-1 do
    local hk=hotkeys[idx][i]
    if hk==self then tremove(hotkeys[idx],i) -- this hotkey will go to the top of the stack
    elseif hk.enabled then log.i('Disabled previous hotkey '..hk.msg) end --shadow previous hotkeys
    hk._hk:disable() --objc
  end
  self.enabled = true
  local returnVal = self._hk:enable() --objc
  if returnVal ~= nil then
    log[isModal and 'df' or 'f']('Enabled hotkey %s%s',self.msg,isModal and ' (in modal)' or '')
    tinsert(hotkeys[idx],self) -- bring to the top of the stack
--   return returnVal
    return self
  else
    self.enabled = false
    return nil
  end
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
  for i=#hotkeys[idx],1,-1 do --scan the stack top-to-bottom
    if hotkeys[idx][i].enabled then
      log.i('Re-enabled previous hotkey '..hotkeys[idx][i].msg)
      hotkeys[idx][i]._hk:enable() --unshadow previous top dog and exit
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
  for i,hk in ipairs(hotkeys[idx]) do if hk==self then tremove(hotkeys[idx],i) break end end
  log.i('Deleted hotkey '..self.msg)
  for k in pairs(self) do self[k]=nil end --gc
end


local function getMods(mods)
  local r={}
  if not mods then return r end
  if type(mods)=='table' then mods=tconcat(mods,'-') end
  if type(mods)~='string' then error('mods must be a string or a table of strings',3) end
  -- super simple substring search for mod names in a string
  mods=slower(mods)
  local function find(ps)
    for _,s in ipairs(ps) do
      if sfind(mods,s,1,true) then r[#r+1]=ps[#ps] return end
    end
  end
  find{'cmd','command','⌘'} find{'ctrl','control','⌃'}
  find{'alt','option','⌥'} find{'shift','⇧'}
  return r --pass a list of unicode symbols to objc
end

local CONCAVE_DIAMOND='✧' -- used for HYPER
local function getIndex(modsID,keycode) -- key for hotkeys table
  local mods = getMods(modsID)
  mods = #mods>=4 and CONCAVE_DIAMOND or tconcat(mods)
  local key=keycodes.map[keycode]
  key=key and supper(key) or '[#'..keycode..']'
  return mods..key
end

local function getFunc(f)
  if f == nil then return nil end
  if type(f) == 'function' then return f end
  if type(f) == 'table' then
    local m = getmetatable(f)
    if m and m.__call and type(m.__call) == 'function' then
      return function() m.__call(f) end
    end
  end
  return nil
end

--- hs.hotkey.new(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> hs.hotkey object
--- Constructor
--- Creates a new hotkey
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been
---    triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * A new `hs.hotkey` object or nil if the hotkey could not be enabled
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
  -- message can be omitted
  if message==nil or getFunc(message) then
    repeatfn=releasedfn releasedfn=pressedfn pressedfn=message message=nil -- shift down arguments
  end
  pressedfn = getFunc(pressedfn)
  releasedfn = getFunc(releasedfn)
  repeatfn = getFunc(repeatfn)
  if not pressedfn and not releasedfn and not repeatfn then
    error('At least one of pressedfn, releasedfn or repeatfn must be a function',2) end
  if type(message)~='string' then message=nil end
  local idx = getIndex(mods,keycode)
  local msg=(message and #message>0) and idx..': '..message or idx
  if message then
    local actualfn=pressedfn or releasedfn or repeatfn -- which function will be wrapped to provide an alert (the first valid one)
    local fnalert=function()alert(msg,hotkey.alertDuration or 0)actualfn()end -- wrapper
    if pressedfn then pressedfn=fnalert -- substitute 'actualfn' with wrapper
    elseif releasedfn then releasedfn=fnalert
    elseif repeatfn then repeatfn=fnalert end
  end
  -- the lightweight hotkey object; _hk=objc userdata; then msg, idx, and the methods
  local hk = {_hk=hotkey._new(mods, keycode, pressedfn, releasedfn, repeatfn),enable=enable,disable=disable,delete=delete,msg=msg,idx=idx}
  log.v('Created hotkey for '..idx)
  local h = hotkeys[idx] or {} -- create stack if this is the first hotkey for a given key combo
  h[#h+1] = hk -- go on top of the stack
  hotkeys[idx] = h
  return hk
end

--- hs.hotkey.systemAssigned(mods, key) -> table | false
--- Function
--- Examine whether a potential hotkey is in use by the macOS system such as the Screen Capture, Universal Access, and Keyboard Navigation keys.
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---
--- Returns:
---  * if the hotkey combination is in use by a system function, returns a table containing the following keys:
---    * keycode - the numberic keycode for the hotkey
---    * mods    - a numeric representation of the modifier flags for the htokey
---    * enabled - a boolean indicating whether or not the key is currently enabled
---  * if the hotkey combination is not in use by the operating system, returns the boolean value `false`
---
--- Notes:
---  * this is provided for informational purposes and does not provide a reliable test as to whether or not Hammerspoon can use the combination to create a custom hotkey -- some combinations which return a table can be over-ridden by Hammerspoon while others cannot.  See also [hs.hotkey.assignable](#assignable).
local originalSystemAssigned = hotkey.systemAssigned
function hotkey.systemAssigned(mods, key)
  local keycode = getKeycode(key)
  mods = getMods(mods)
  return originalSystemAssigned(mods, keycode)
end

--- hs.hotkey.assignable(mods, key) -> boolean
--- Function
--- Determines whether the hotkey combination can be assigned a callback through Hammerspoon.
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---
--- Returns:
---  * a boolean value, true if the hotkey combination can be given an assignment by Hammerspoon or false if it cannot.
---
--- Notes:
---  * The most common reason a hotkey combination cannot be given an assignment by Hammerspoon is because it is in use by the Mac operating system -- see the Shortcuts tab of Keyboard in the System Preferences application or [hs.hotkey.systemAssigned](#systemAssigned).
function hotkey.assignable(mods, key)
    local k = hotkey.new(mods, key, function() end)
    local prevLevel = hs.luaSkinLog.level
    -- supress luaSkinLog error if binding fails
    hs.luaSkinLog.level = 0
    local status = k._hk:enable()
    if status then k._hk:disable() end
    k.enabled = false
    hs.luaSkinLog.level = prevLevel
    return status and true or false
end

--- hs.hotkey.disableAll(mods, key)
--- Function
--- Disables all previously set callbacks for a given keyboard combination
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
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
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
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
--- Creates (and enables) a hotkey that shows all currently active hotkeys (i.e. enabled and not "shadowed" in the current context) while pressed
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---
--- Returns:
---  * The new `hs.hotkey` object

local helpHotkey
function hotkey.getHotkeys()
  local t={}
  for _,hks in pairs(hotkeys) do
    for i=#hks,1,-1 do
      if hks[i].enabled and hks[i]~=helpHotkey then
        t[#t+1] = hks[i]
        break
      end
    end
  end
  tsort(t,function(a,b)if#a.idx==#b.idx then return a.idx<b.idx else return #a.idx<#b.idx end end)
  if helpHotkey then tinsert(t,1,helpHotkey) end
  return t
end

local function showHelp()
  local t=hotkey.getHotkeys()
  --  hs.alert(helpHotkey.msg,3600)
  local s=''
  for i=2,#t do s=s..t[i].msg..'\n' end
  alert(s:sub(1,-2),3600)
end
function hotkey.showHotkeys(mods,key)
  if helpHotkey then delete(helpHotkey) end
  helpHotkey = hotkey.bind(mods,key,'Show active hotkeys',showHelp,alert.closeAll)
  return helpHotkey
end

--- hs.hotkey.bind(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> hs.hotkey object
--- Constructor
--- Creates a new hotkey and enables it immediately
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
---  * message - (optional) A string containing a message to be displayed via `hs.alert()` when the hotkey has been
---    triggered; if omitted, no alert will be shown
---  * pressedfn - A function that will be called when the hotkey has been pressed, or nil
---  * releasedfn - A function that will be called when the hotkey has been released, or nil
---  * repeatfn - A function that will be called when a pressed hotkey is repeating, or nil
---
--- Returns:
---  * A new `hs.hotkey` object or nil if the hotkey could not be enabled
---
--- Notes:
---  * This function is just a wrapper that performs `hs.hotkey.new(...):enable()`
---  * You can create multiple `hs.hotkey` objects for the same keyboard combination, but only one can be active
---    at any given time - see `hs.hotkey:enable()`
---  * If `message` is the empty string `""`, the alert will just show the triggered keyboard combination
---  * If you don't want any alert, you must *actually* omit the `message` parameter; a `nil` in 3rd position
---    will be interpreted as a missing `pressedfn`
---  * You must pass at least one of `pressedfn`, `releasedfn` or `repeatfn`; to delete a hotkey, use `hs.hotkey:delete()`
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

--- hs.hotkey.bindSpec(keyspec, ...) -> hs.hotkey object
--- Constructor
--- Creates a hotkey and enables it immediately
---
--- Parameters:
---  * keyspec - A table containing two items:
---   * first, a table containing keyboard modifiers, as specified in `hs.hotkey.bind()`
---   * second, a string containing the name of a keyboard key, as specified in `hs.hotkey.bind()`
---  * ... - All remaining arguments are as specified in `hs.hotkey.bind()`
---
--- Returns:
---  * A new `hs.hotkey` object for method chaining
---
--- Notes:
---  * This function is just a wrapper that performs `hs.hotkey.bind(keyspec[1], keyspec[2], ...)`
function hotkey.bindSpec(keyspec, ...)
  return hotkey.bind(keyspec[1], keyspec[2], ...)
end

--- === hs.hotkey.modal ===
---
--- Create/manage modal keyboard shortcut environments
---
--- Usage:
--- ```lua
--- k = hs.hotkey.modal.new('cmd-shift', 'd')
--- function k:entered() hs.alert'Entered mode' end
--- function k:exited()  hs.alert'Exited mode'  end
--- k:bind('', 'escape', function() k:exit() end)
--- k:bind('', 'J', 'Pressed J',function() print'let the record show that J was pressed' end)```

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
function hotkey.modal:entered() -- luacheck: ignore
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
function hotkey.modal:exited() -- luacheck: ignore
end

--- hs.hotkey.modal:bind(mods, key, message, pressedfn, releasedfn, repeatfn) -> hs.hotkey.modal object
--- Method
--- Creates a hotkey that is enabled/disabled as the modal is entered/exited
---
--- Parameters:
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
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
---  * mods - A table or a string containing (as elements, or as substrings with any separator) the keyboard modifiers required,
---    which should be zero or more of the following:
---    * "cmd", "command" or "⌘"
---    * "ctrl", "control" or "⌃"
---    * "alt", "option" or "⌥"
---    * "shift" or "⇧"
---  * key - A string containing the name of a keyboard key (as found in [hs.keycodes.map](hs.keycodes.html#map) ), or a raw keycode number
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

--- hs.hotkey.modal:delete()
--- Method
--- Deletes a modal hotkey object without calling :exited()
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function hotkey.modal:delete()
  for _,hk in ipairs(self.keys) do
    delete(hk)
  end
  if (self.k) then
    self.k:delete()
  end
end

return hotkey
