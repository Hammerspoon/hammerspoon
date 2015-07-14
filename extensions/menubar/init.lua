--- === hs.menubar ===
---
--- Create and manage menubar icons

local menubar = require "hs.menubar.internal"
local imagemod = require("hs.image")

-- This is the wrapper for hs.menubar:setIcon(). It is documented in internal.m

local tmp = menubar.new()
local tmpmetatable = getmetatable(tmp)

tmpmetatable.setIcon = function(object, imagePath)
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

tmp:delete()

return menubar
