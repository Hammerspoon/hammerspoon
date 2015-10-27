
local imagemod    = require("hs.image") -- make sure we know about hsimage userdata for image functions

local module      = require("hs.drawing.internal")
module.color      = require("hs.drawing.color")
local styledtext  = require("hs.styledtext")

local _kMetaTable = {}
_kMetaTable._k = {}
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    return results
end

local fnutils = require("hs.fnutils")
local imagemod = require("hs.image")

local drawingObject = hs.getObjectMetatable("hs.drawing")

module.fontTraits      = _makeConstantsTable(module.fontTraits)
module.windowBehaviors = _makeConstantsTable(module.windowBehaviors)
module.windowLevels    = _makeConstantsTable(module.windowLevels)

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
module.setImageFromPath = function(self, path)
    local image = nil
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
module.setImagePath = module.setImageFromPath

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
module.setImageFromASCII = function(self, ascii)
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
---  * An `hs.drawing` image object, or nil if an error occurs
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
    for i,v in ipairs(stringTable) do
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

module.fontNames =           styledtext.fontNames
module.fontNamesWithTraits = styledtext.fontNamesWithTraits
module.fontTraits =          styledtext.fontTraits

return module
