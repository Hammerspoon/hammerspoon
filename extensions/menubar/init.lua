--- === hs.menubar ===
---
--- Create and manage menubar icons

local menubar = require "hs.menubar.internal"
local imagemod = require("hs.image")
local geometry = require "hs.geometry"
local screen = require "hs.screen"

require("hs.styledtext")

-- This is the wrapper for hs.menubar:setIcon(). It is documented in internal.m

local menubarObject = hs.getObjectMetatable("hs.menubar")

menubarObject.setIcon = function(object, imagePath)
    local tmpImage = nil

    if type(imagePath) == "userdata" then
        tmpImage = imagePath
    elseif type(imagePath) == "string" then
        if string.sub(imagePath, 1, 6) == "ASCII:" then
            tmpImage = imagemod.imageFromASCII(string.sub(imagePath, 7, -1))
        else
            tmpImage = imagemod.imageFromPath(imagePath)
        end
    end

    return object:_setIcon(tmpImage)
end

--- hs.menubar:frame() -> hs.geometry rect
--- Method
--- Returns the menubar item frame
---
--- Parameters
---  * None
---
--- Returns:
---  * an hs.geometry rect describing the menubar item's frame
---
--- Notes:
---  * This will return a frame even if no icon or title is set

function menubarObject:frame()
    local sf = screen.mainScreen():fullFrame()
    local f = self:_frame()
    f.y = sf.h - f.y - f.h
    return geometry(f)
end

return menubar
