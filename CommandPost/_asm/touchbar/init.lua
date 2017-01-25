
--- === hs._asm.touchbar ===
---
--- A module to display an on-screen representation of the Apple Touch Bar, even on machines which do not have the touch bar.
---
--- This code is based heavily on code found at https://github.com/bikkelbroeders/TouchBarDemoApp.  Unlike the code found at the provided link, this module only supports displaying the touch bar window on your computer screen - it does not support display on an attached iDevice.
---
--- This module requires that you are running macOS 10.12.1 build 16B2657 or greater.  Most people who have received the 10.12.1 update have an earlier build, which you can check by selecting "About this Mac" from the Apple menu and then clicking the mouse pointer on the version number displayed in the dialog box.  If you require an update, you can find it at https://support.apple.com/kb/dl1897.
---
--- If you wish to use this module in an environment where the end-user's machine may not have the correct macOS release version, you should always check the value of `hs._asm.touchbar.supported` before trying to create the Touch Bar and provide your own fallback or message.  Failure to do so will cause your code to break to the Hammerspoon Console when you attempt to create and use the Touch Bar.

local USERDATA_TAG = "hs._asm.touchbar"
local module       = require(USERDATA_TAG..".supported")
if module.supported() then
    for k, v in pairs(require(USERDATA_TAG..".internal")) do module[k] = v end
end


-- if the userdata table was not created (i.e. we're on an unsupported machine), go ahead
-- and stick the "wrapped" methods into an empty table... it will be garbage collected after
-- the module is loaded, so no big deal.
local objectMT     = hs.getObjectMetatable(USERDATA_TAG) or {}
local mouse        = require("hs.mouse")
local screen       = require("hs.screen")

require("hs.drawing.color")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs._asm.touchbar:toggle([duration]) -> touchbarObject
--- Method
--- Toggle's the visibility of the touch bar window.
---
--- Parameters:
---  * `duration` - an optional number, default 0.0, specifying the fade-in/out time when changing the visibility of the touch bar window.
---
--- Returns:
---  * the touchbarObject
objectMT.toggle = function(self, ...)
    return self:isVisible() and self:hide(...) or self:show(...)
end

--- hs._asm.touchbar:atMousePosition() -> touchbarObject
--- Method
--- Moves the touch bar window so that it is centered directly underneath the mouse pointer.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the touchbarObject
---
--- Notes:
---  * This method mimics the display location as set by the sample code this module is based on.  See https://github.com/bikkelbroeders/TouchBarDemoApp for more information.
---  * The touch bar position will be adjusted so that it is fully visible on the screen even if this moves it left or right from the mouse's current position.
objectMT.atMousePosition = function(self)
    local origin    = mouse.getAbsolutePosition()
    local tbFrame   = self:getFrame()
    local scFrame   = mouse.getCurrentScreen():fullFrame()
    local scRight   = scFrame.x + scFrame.w
    local scBottom  = scFrame.y + scFrame.h

    origin.x = origin.x - tbFrame.w * 0.5
--     origin.y = origin.y - tbFrame.h -- Hammerspoon's 0,0 is the topLeft

    if origin.x < scFrame.x then origin.x = scFrame.x end
    if origin.x + tbFrame.w > scRight then origin.x = scRight - tbFrame.w end
    if origin.y + tbFrame.h > scBottom then origin.y = scBottom - tbFrame.h end
    return self:topLeft(origin)
end

--- hs._asm.touchbar:centered([top]) -> touchbarObject
--- Method
--- Moves the touch bar window to the top or bottom center of the main screen.
---
--- Parameters:
---  * `top` - an optional boolean, default false, specifying whether the touch bar should be centered at the top (true) of the screen or at the bottom (false).
---
--- Returns:
---  * the touchbarObject
objectMT.centered = function(self, top)
    top = top or false

    local origin    = {}
    local tbFrame   = self:getFrame()
    local scFrame   = screen.mainScreen():fullFrame()
--     local scRight   = scFrame.x + scFrame.w
    local scBottom  = scFrame.y + scFrame.h

    origin.x = scFrame.x + (scFrame.w - tbFrame.w) / 2
    origin.y = top and scFrame.y or (scBottom - tbFrame.h)
    return self:topLeft(origin)
end

-- Return Module Object --------------------------------------------------

return module
