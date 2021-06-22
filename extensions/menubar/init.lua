--- === hs.menubar ===
---
--- Create and manage menubar icons

local menubar = require "hs.menubar.internal"
local imagemod = require("hs.image")
local geometry = require "hs.geometry"
local screen = require "hs.screen"

require("hs.styledtext")

-- protects tables of constants

menubar.priorities = ls.makeConstantsTable(menubar.priorities)

-- This is the wrapper for hs.menubar:setIcon(). It is documented in internal.m

local menubarObject = hs.getObjectMetatable("hs.menubar")

menubarObject.setIcon = function(object, imagePath, template)
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

    return object:_setIcon(tmpImage, template)
end

--- hs.menubar:frame() -> hs.geometry rect
--- Method
--- Returns the menubar item frame
---
--- Parameters:
---  * None
---
--- Returns:
---  * an hs.geometry rect describing the menubar item's frame or nil if the menubar item is not currently in the menubar.
---
--- Notes:
---  * This will return a frame even if no icon or title is set

function menubarObject:frame()
    local sf = screen.mainScreen():fullFrame()
    local f = self:_frame()
    if f then
        f.y = sf.h - f.y - f.h
        return geometry(f)
    else
        return nil
    end
end

return menubar
