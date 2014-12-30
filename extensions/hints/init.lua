--- === hs.hints ===
---
--- Switch focus with a transient per-application hotkey

local hints = require "hs.hints.internal"
local screen = require "hs.screen"
local window = require "hs.window"
local hotkey = require "hs.hotkey"
local modal_hotkey = hotkey.modal

--- hs.hints.hintChars
--- Variable
--- This controls the set of characters that will be used for window hints. They must be characters found in hs.keycodes.map
--- The default is the letters A-Z, the numbers 0-9, and the punctuation characters: -=[];'\\,./\`
hints.hintChars = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}

--- hs.hints.style
--- Variable
--- If this is set to "vimperator", every window hint starts with the first character
--- of the parent application's title
hints.style = "vimperator"

local openHints = {}
local takenPositions = {}
local hintDict = {}
local modalKey = nil

local bumpThresh = 40^2
local bumpMove = 80

function hints.bumpPos(x,y)
  for i, pos in ipairs(takenPositions) do
    if ((pos.x-x)^2 + (pos.y-y)^2) < bumpThresh then
      return hints.bumpPos(x,y+bumpMove)
    end
  end
  return {x = x,y = y}
end

function hints.addWindow(dict, win)
  local n = dict['count']
  if n == nil then
    dict['count'] = 0
    n = 0
  end
  local m = (n % #hints.hintChars) + 1
  local char = hints.hintChars[m]
  if n < #hints.hintChars then
    dict[char] = win
  else
    if type(dict[char]) == "userdata" then
      -- dict[m] is already occupied by another window
      -- which me must convert into a new dictionary
      local otherWindow = dict[char]
      dict[char] = {}
      hints.addWindow(dict, otherWindow)
    end
    hints.addWindow(dict[char], win)
  end
  dict['count'] = dict['count'] + 1
end

function hints.displayHintsForDict(dict, prefixstring)
  for key, val in pairs(dict) do
    if type(val) == "userdata" then -- this is a window
      local win = val
      local app = win:application()
      local fr = win:frame()
      local sfr = win:screen():frame()
      if app and win:title() ~= "" and win:isStandard() then
        local c = {x = fr.x + (fr.w/2) - sfr.x, y = fr.y + (fr.h/2) - sfr.y}
        c = hints.bumpPos(c.x, c.y)
        if c.y < 0 then
          print("hs.hints: Skipping offscreen window: "..win:title())
        else
          -- print(win:title().." x:"..c.x.." y:"..c.y) -- debugging
          local hint = hints.new(c.x, c.y, prefixstring .. key, app:bundleID(), win:screen())
          table.insert(takenPositions, c)
          table.insert(openHints, hint)
        end
      end
    elseif type(val) == "table" then -- this is another window dict
      hints.displayHintsForDict(val, prefixstring .. key)
    end
  end
end

function hints.processChar(char)
  if hintDict[char] ~= nil then
    hints.closeHints()
    if type(hintDict[char]) == "userdata" then
      if hintDict[char] then hintDict[char]:focus() end
      modalKey:exit()
    elseif type(hintDict[char]) == "table" then
      hintDict = hintDict[char]
      takenPositions = {}
      hints.displayHintsForDict(hintDict, "")
    end
  end
end

function hints.setupModal()
  k = modal_hotkey.new(nil, nil)
  k:bind({}, 'escape', function() hints.closeHints(); k:exit() end)

  for _, c in ipairs(hints.hintChars) do
    k:bind({}, c, function() hints.processChar(c) end)
  end
  return k
end

--- hs.hints.windowHints()
--- Function
--- Displays a keyboard hint for switching focus to each window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * If there are more windows open than there are characters available in hs.hints.hintChars,
---    we resort to multi-character hints
---  * If hints.style is set to "vimperator", every window hint is prefixed with the first
---    character of the parent application's name
function hints.windowHints()
  if (modalKey == nil) then
    modalKey = hints.setupModal()
  end
  hints.closeHints()
  hintDict = {}
  for i, win in ipairs(window.allWindows()) do
    local app = win:application()
    if hints.style == "vimperator" then
      if app and win:title() ~= "" and win:isStandard() then
        local appchar = string.upper(string.sub(app:title(), 1, 1))
        modalKey:bind({}, appchar, function() hints.processChar(appchar) end)
        if hintDict[appchar] == nil then
          hintDict[appchar] = {}
        end
        hints.addWindow(hintDict[appchar], win)
      end
    else
      hints.addWindow(hintDict, win)
    end
  end
  takenPositions = {}
  hints.displayHintsForDict(hintDict, "")
  modalKey:enter()
end

function hints.closeHints()
  for _, hint in ipairs(openHints) do
    hint:close()
  end
  openHints = {}
  takenPositions = {}
end

return hints
