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
hints.hintChars = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
                   "1","2","3","4","5","6","7","8","9","0",
                   "-","=","[","]",";","'","\\",",",".","/","`"}

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

function hints.createHandler(char)
  return function()
    local win = hintDict[char]
    if win then win:focus() end
    hints.closeHints()
    modalKey:exit()
  end
end

function hints.setupModal()
  k = modal_hotkey.new({"cmd", "shift"}, "V")
  k:bind({}, 'escape', function() hints.closeHints(); k:exit() end)

  for i,c in ipairs(hints.hintChars) do
    k:bind({}, c, hints.createHandler(c))
  end
  return k
end
modalKey = hints.setupModal()

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
---  * If there are more windows open than there are characters available in hs.hints.hintChars, not all windows will receive a hint, and an error will be logged to the Hammerspoon Console
function hints.windowHints()
  hints.closeHints()

  local numHints = 0
  for i,_ in ipairs(hints.hintChars) do
      numHints = numHints + 1
  end

  for i,win in ipairs(window.allWindows()) do
    local app = win:application()
    local fr = win:frame()
    local sfr = win:screen():frame()
    if app and win:title() ~= "" and win:isStandard() then
      local c = {x = fr.x + (fr.w/2) - sfr.x, y = fr.y + (fr.h/2) - sfr.y}
      c = hints.bumpPos(c.x, c.y)
      if c.y < 0 then
          print("hs.hints: Skipping offscreen window: "..win:title())
      else
        --print(win:title().." x:"..c.x.." y:"..c.y) -- debugging
        -- Check there are actually hint keys available
        local numOpenHints = 0
        for x,_ in ipairs(openHints) do
            numOpenHints = numOpenHints + 1
        end
        if numOpenHints < numHints then
          local hint = hints.new(c.x,c.y,hints.hintChars[numOpenHints+1],app:bundleID(),win:screen())
          hintDict[hints.hintChars[numOpenHints+1]] = win
          table.insert(takenPositions, c)
          table.insert(openHints, hint)
        else
          print("hs.hints: Error: more windows than we have hint keys defined. See docs for hs.hints.hintChars")
        end
      end
    end
  end
  modalKey:enter()
end

function hints.closeHints()
  for i, hint in ipairs(openHints) do
    hint:close()
  end
  openHints = {}
  hintDict = {}
  takenPositions = {}
end

return hints
