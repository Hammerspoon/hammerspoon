
if require"hs.settings".get("useCanvasWrappedDrawing") then
    return require("hs.drawing.canvasWrapper")
end

-- Make sure we know about hsimage userdata for image functions:
local imagemod    = require("hs.image") -- luacheck: ignore

local module      = require("hs.drawing.internal")
module.color      = require("hs.drawing.color")
local styledtext  = require("hs.styledtext")

local drawingObject = hs.getObjectMetatable("hs.drawing")

--module.fontTraits      = ls.makeConstantsTable(module.fontTraits) -- inherited below
module.windowBehaviors = ls.makeConstantsTable(module.windowBehaviors)
module.windowLevels    = ls.makeConstantsTable(module.windowLevels)

--- hs.drawing:setImageFromPath(imagePath) -> drawingObject
--- Method
--- Sets the image path of a drawing object
---
--- Parameters:
---  * imagePath - A string containing the path to an image file
---
--- Returns:
---  * The drawing object
---
--- Notes:
---  * This method should only be used on an image drawing object
---  * Paths relative to the PWD of Hammerspoon (typically ~/.hammerspoon/) will work, but paths relative to the UNIX homedir character, `~` will not
---  * Animated GIFs are supported. They're not super friendly on your CPU, but they work
drawingObject.setImageFromPath = function(self, path)
    local image
    -- Legacy support for ASCII here. Really people should use :setImageFromASCII()
    if string.sub(path, 1, 6) == "ASCII:" then
        image = imagemod.imageFromASCII(string.sub(path, 7, -1))
    else
        image = imagemod.imageFromPath(path)
    end

    if image then
        self:setImage(image)
    end

    return self
end
-- Legacy support of an old API
drawingObject.setImagePath = drawingObject.setImageFromPath

--- hs.drawing:setImageASCII(ascii) -> drawingObject
--- Method
--- Sets the image of a drawing object from an ASCII representation
---
--- Parameters:
---  * ascii - A string containing the ASCII image to render
---
--- Returns:
---  * The drawing object
---
--- Notes:
---  * To use the ASCII diagram image support, see http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/
drawingObject.setImageFromASCII = function(self, ascii)
    if string.sub(ascii, 1, 6) == "ASCII:" then
        ascii = string.sub(ascii, 7, -1)
    end
    local image = imagemod.imageFromASCII(ascii)

    if image then
        self:setImage(image)
    end

    return self
end

-- This is the wrapper for hs.drawing.image(). It is documented in internal.m
module.image = function(sizeRect, imagePath)
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

    if tmpImage then
        return module._image(sizeRect, tmpImage)
    else
        return nil
    end
end

--- hs.drawing.appImage(sizeRect, bundleID) -> drawingObject or nil
--- Constructor
--- Creates a new image object with the icon of a given app
---
--- Parameters:
---  * sizeRect - A rect-table containing the location/size of the image. If the size values are -1 then the image will be displayed at the icon's native size
---  * bundleID - A string containing the bundle identifier of an app (e.g. "com.apple.Safari")
---
--- Returns:
---  * An `hs.drawing` object, or nil if an error occurs
module.appImage = function(sizeRect, bundleID)
    local tmpImage = imagemod.imageFromAppBundle(bundleID)
    if tmpImage then
        return module._image(sizeRect, tmpImage)
    else
        return nil
    end
end

--- hs.drawing:setBehaviorByLabels(table) -> object
--- Method
--- Sets the window behaviors based upon the labels specified in the table provided.
---
--- Parameters:
---  * a table of label strings or numbers.  Recognized values can be found in `hs.drawing.windowBehaviors`.
---
--- Returns:
---  * The `hs.drawing` object
drawingObject.setBehaviorByLabels = function(obj, stringTable)
    local newBehavior = 0
    for _,v in ipairs(stringTable) do
        local flag = tonumber(v) or module.windowBehaviors[v]
        if flag then newBehavior = newBehavior | flag end
    end
    return obj:setBehavior(newBehavior)
end

--- hs.drawing:behaviorAsLabels() -> table
--- Method
--- Returns a table of the labels for the current behaviors of the object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Returns a table of the labels for the current behaviors with respect to Spaces and Exposé for the object.
drawingObject.behaviorAsLabels = function(obj)
    local results = {}
    local behaviorNumber = obj:behavior()

    if behaviorNumber ~= 0 then
        for i, v in pairs(module.windowBehaviors) do
            if type(i) == "string" then
                if (behaviorNumber & v) > 0 then table.insert(results, i) end
            end
        end
    else
        table.insert(results, module.windowBehaviors[0])
    end
    return setmetatable(results, { __tostring = function(_)
        table.sort(_)
        return "{ "..table.concat(_, ", ").." }"
    end})
end

--- hs.drawing.arc(centerPoint, radius, startAngle, endAngle) -> drawingObject or nil
--- Constructor
--- Creates a new arc object
---
--- Parameters:
---  * centerPoint - A point-table containing the center of the circle used to define the arc
---  * radius      - The radius of the circle used to define the arc
---  * startAngle  - The starting angle of the arc, measured in degrees clockwise from the y-axis.
---  * endAngle    - The ending angle of the arc, measured in degrees clockwise from the y-axis.
---
--- Returns:
---  * An `hs.drawing` object, or nil if an error occurs
---
--- Notes:
---  * This constructor is actually a wrapper for the `hs.drawing.ellipticalArc` constructor.
module.arc = function(centerPoint, radius, startAngle, endAngle)
    local rect = {
        x = (centerPoint.x or 0.0) - radius,
        y = (centerPoint.y or 0.0) - radius,
        h = (radius * 2.0) or 0.0,
        w = (radius * 2.0) or 0.0
    }
    return module.ellipticalArc(rect, startAngle, endAngle)
end

module.fontNames =           styledtext.fontNames
module.fontNamesWithTraits = styledtext.fontNamesWithTraits
module.fontTraits =          styledtext.fontTraits

return module
