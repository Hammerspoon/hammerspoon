local tabbing = {}

tabbing.HEIGHT = 18
local val1 = 0.9
local val2 = 0.5
local val3 = 0.3
tabbing.STARTCOLOR = { red=val1, blue=val1, green=val1, alpha=1 }
tabbing.ENDCOLOR= { red=val2, blue=val2, green=val2, alpha=1 }
tabbing.TEXTCOLOR = { red=val3, blue=val3, green=val3, alpha=1 }

local drawing = require 'hs.drawing'

function tabbing.drawTabs(region)
  local winCount = #region.windows
  local width = region.w / winCount
  for i = winCount, 1, -1 do
    local win = region.windows[i]
    local posX = region.x + width * (winCount - i)
    local rectSize = {
      x = posX,
      y = region.y,
      w = width,
      h = tabbing.HEIGHT }
    local titleSize = {
      x = posX + 2,
      y = region.y,
      w = width - 2,
      h = tabbing.HEIGHT }
    local rect = drawing.rectangle(rectSize)
    local winName = nil
    local winTitle = win:title()
    local appTitle = win:application():title()
    if winTitle ~= appTitle then
      winName = appTitle .. " - " .. winTitle
    else
      winName = appTitle
    end
    local title = drawing.text(titleSize, winName)
    rect:setFillGradient(tabbing.STARTCOLOR, tabbing.ENDCOLOR, 90)
    title:setTextSize(12)
    title:setTextColor(12)
    rect:show()
    title:show()
  end
end


return tabbing
