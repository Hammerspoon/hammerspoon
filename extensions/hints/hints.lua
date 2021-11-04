--- === hs.hints ===
---
--- Switch focus with a transient per-application keyboard shortcut

local hints = require "hs.libhints"
local window = require "hs.window"
local hotkey = require "hs.hotkey"
local modal_hotkey = hotkey.modal

--- hs.hints.hintChars
--- Variable
--- This controls the set of characters that will be used for window hints. They must be characters found in hs.keycodes.map
--- The default is the letters A-Z. Note that if `hs.hints.style` is set to "vimperator", this variable will be ignored.
hints.hintChars = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}

-- vimperator mode requires to use full set of alphabet to represent applications.
hints.hintCharsVimperator = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}

--- hs.hints.style
--- Variable
--- If this is set to "vimperator", every window hint starts with the first character
--- of the parent application's title
hints.style = "default"

--- hs.hints.fontName
--- Variable
--- A fully specified family-face name, preferrably the PostScript name, such as Helvetica-BoldOblique or Times-Roman. (The Font Book app displays PostScript names of fonts in the Font Info panel.)
--- The default value is the system font
hints.fontName = nil

--- hs.hints.fontSize
--- Variable
--- The size of font that should be used. A value of 0.0 will use the default size.
hints.fontSize = 0.0

--- hs.hints.showTitleThresh
--- Variable
--- If there are less than or equal to this many windows on screen their titles will be shown in the hints.
--- The default is 4. Setting to 0 will disable this feature.
hints.showTitleThresh = 4

--- hs.hints.titleMaxSize
--- Variable
--- If the title is longer than maxSize, the string is truncated, -1 to disable, valid value is >= 6
hints.titleMaxSize = -1

--- hs.hints.iconAlpha
--- Variable
--- Opacity of the application icon. Default is 0.95.
hints.iconAlpha = 0.95

local openHints = {}
local takenPositions = {}
local hintDict = {}
local hintChars = nil
local modalKey = nil
local selectionCallback = nil

local bumpThresh = 40^2
local bumpMove = 80

local invalidWindowRoles = {
   AXScrollArea = true, --This excludes the main finder window.
   AXUnknown = true
}

local function isValidWindow(win, allowNonStandard)
   if not allowNonStandard then
      return win:isStandard()
   else
      return invalidWindowRoles[win:role()] == nil
   end
end

function hints.bumpPos(x,y)
  for _, pos in ipairs(takenPositions) do
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
  local m = (n % #hintChars) + 1
  local char = hintChars[m]
  if n < #hintChars then
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

-- Private helper to recursively find the total number of hints in a dict
function hints._dictSize(t)
  if type(t) == "userdata" and t:screen() then -- onscreen window
    return 1
  elseif type(t) == "table" then
    local count = 0
    for _,v in pairs(t) do count = count + hints._dictSize(v) end
    return count
  end
  return 0 -- screenless window or something else
end

function hints.displayHintsForDict(dict, prefixstring, showTitles, allowNonStandard)
  if showTitles == nil then
    showTitles = hints._dictSize(hintDict) <= hints.showTitleThresh
  end
  for key, val in pairs(dict) do
    if type(val) == "userdata" and val:screen() then -- this is an onscreen window
      local win = val
      local app = win:application()
      local fr = win:frame()
      local sfr = win:screen():frame()
      if app and app:bundleID() and isValidWindow(win, allowNonStandard) then
        local c = {x = fr.x + (fr.w/2) - sfr.x, y = fr.y + (fr.h/2) - sfr.y}
        local d = hints.bumpPos(c.x, c.y)
        if d.y > (sfr.y + sfr.h - bumpMove) then
            d.x = d.x + bumpMove
            d.y = fr.y + (fr.h/2) - sfr.y
            d = hints.bumpPos(d.x, d.y)
        end
        c = d
        if c.y < 0 then
          print("hs.hints: Skipping offscreen window: "..win:title())
        else
          local suffixString = ""
          if showTitles then
            local win_title = win:title()
            if hints.titleMaxSize > 1 and #win_title > hints.titleMaxSize then
                local end_idx = math.max(0, hints.titleMaxSize-3)
                win_title = string.sub(win_title, 1, end_idx) .. "..."
            end
            suffixString = ": "..win_title
          end
          -- print(win:title().." x:"..c.x.." y:"..c.y) -- debugging
          local hint = hints.new(c.x, c.y, prefixstring .. key .. suffixString, app:bundleID(), win:screen(), hints.fontName, hints.fontSize, hints.iconAlpha)
          table.insert(takenPositions, c)
          table.insert(openHints, hint)
        end
      end
    elseif type(val) == "table" then -- this is another window dict
      hints.displayHintsForDict(val, prefixstring .. key, showTitles, allowNonStandard)
    end
  end
end

function hints.processChar(char)
  local toFocus = nil

  if hintDict[char] ~= nil then
    hints.closeHints()
    if type(hintDict[char]) == "userdata" then
      if hintDict[char] then
          toFocus = hintDict[char]
      end
    elseif type(hintDict[char]) == "table" then
      hintDict = hintDict[char]
      if hintDict.count == 1 then
        toFocus = hintDict[hintChars[1]]
      else
        takenPositions = {}
        hints.displayHintsForDict(hintDict, "")
      end
    end
  end

  if toFocus then
      toFocus:focus()
      modalKey:exit()
      if selectionCallback then
          selectionCallback(toFocus)
      end
  end
end

function hints.setupModal()
  local k = modal_hotkey.new(nil, nil)
  k:bind({}, 'escape', function() hints.closeHints(); k:exit() end)

  for _, c in ipairs(hintChars) do
    k:bind({}, c, function() hints.processChar(c) end)
  end
  return k
end

--- hs.hints.windowHints([windows, callback, allowNonStandard])
--- Function
--- Displays a keyboard hint for switching focus to each window
---
--- Parameters:
---  * windows - An optional table containing some `hs.window` objects. If this value is nil, all windows will be hinted
---  * callback - An optional function that will be called when a window has been selected by the user. The function will be called with a single argument containing the `hs.window` object of the window chosen by the user
---  * allowNonStandard - An optional boolean.  If true, all windows will be included, not just standard windows
---
--- Returns:
---  * None
---
--- Notes:
---  * If there are more windows open than there are characters available in hs.hints.hintChars, multiple characters will be used
---  * If hints.style is set to "vimperator", every window hint is prefixed with the first character of the parent application's name
---  * To display hints only for the currently focused application, try something like:
---   * `hs.hints.windowHints(hs.window.focusedWindow():application():allWindows())`
function hints.windowHints(windows, callback, allowNonStandard)

  if hints.style == "vimperator" then
    hintChars = hints.hintCharsVimperator
  else
    hintChars = hints.hintChars
  end

  windows = windows or window.allWindows()
  selectionCallback = callback

  if (modalKey == nil) then
    modalKey = hints.setupModal()
  end
  hints.closeHints()
  hintDict = {}
  for _, win in ipairs(windows) do
    local app = win:application()
    if app and app:bundleID() and isValidWindow(win, allowNonStandard) then
      if hints.style == "vimperator" then
        local appchar = string.upper(string.sub(app:title(), 1, 1))
        if hintDict[appchar] == nil then
          hintDict[appchar] = {}
        end
        hints.addWindow(hintDict[appchar], win)
      else
        hints.addWindow(hintDict, win)
      end
    end
  end
  takenPositions = {}
  if next(hintDict) ~= nil then
    hints.displayHintsForDict(hintDict, "", nil, allowNonStandard)
    modalKey:enter()
  end
end

function hints.closeHints()
  for _, hint in ipairs(openHints) do
    hint:close()
  end
  openHints = {}
  takenPositions = {}
end

return hints
