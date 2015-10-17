local module = require("hs.drawing.internal")
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

--- hs.drawing.color
--- Constant
--- This table contains various useful pre-defined colors:
---  * osx_red - The same red used for OS X window close buttons
---  * osx_green - The same green used for OS X window zoom buttons
---  * osx_yellow - The same yellow used for OS X window minimize buttons
---  * All the X11 web colors from https://en.wikipedia.org/wiki/Web_colors#X11_color_names (names in lowercase)
---
--- Please feel free to submit additional useful colors :)
module.color = {
    ["osx_green"]   = { ["red"]=0.153,["green"]=0.788,["blue"]=0.251,["alpha"]=1 },
    ["osx_red"]     = { ["red"]=0.996,["green"]=0.329,["blue"]=0.302,["alpha"]=1 },
    ["osx_yellow"]  = { ["red"]=1.000,["green"]=0.741,["blue"]=0.180,["alpha"]=1 },
-- X11 web colors, from https://en.wikipedia.org/wiki/Web_colors#X11_color_names
-- Pink colors
    ["pink"]              = { ["red"]=1.000,["green"]=0.753,["blue"]=0.796,["alpha"]=1 },
    ["lightpink"]         = { ["red"]=1.000,["green"]=0.714,["blue"]=0.757,["alpha"]=1 },
    ["hotpink"]           = { ["red"]=1.000,["green"]=0.412,["blue"]=0.706,["alpha"]=1 },
    ["deeppink"]          = { ["red"]=1.000,["green"]=0.078,["blue"]=0.576,["alpha"]=1 },
    ["palevioletred"]     = { ["red"]=0.859,["green"]=0.439,["blue"]=0.576,["alpha"]=1 },
    ["mediumvioletred"]   = { ["red"]=0.780,["green"]=0.082,["blue"]=0.522,["alpha"]=1 },
-- Red colors
    ["lightsalmon"]       = { ["red"]=1.000,["green"]=0.627,["blue"]=0.478,["alpha"]=1 },
    ["salmon"]            = { ["red"]=0.980,["green"]=0.502,["blue"]=0.447,["alpha"]=1 },
    ["darksalmon"]        = { ["red"]=0.914,["green"]=0.588,["blue"]=0.478,["alpha"]=1 },
    ["lightcoral"]        = { ["red"]=0.941,["green"]=0.502,["blue"]=0.502,["alpha"]=1 },
    ["indianred"]         = { ["red"]=0.804,["green"]=0.361,["blue"]=0.361,["alpha"]=1 },
    ["crimson"]           = { ["red"]=0.863,["green"]=0.078,["blue"]=0.235,["alpha"]=1 },
    ["firebrick"]         = { ["red"]=0.698,["green"]=0.133,["blue"]=0.133,["alpha"]=1 },
    ["darkred"]           = { ["red"]=0.545,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
    ["red"]               = { ["red"]=1.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
-- Orange colors
    ["orangered"]         = { ["red"]=1.000,["green"]=0.271,["blue"]=0.000,["alpha"]=1 },
    ["tomato"]            = { ["red"]=1.000,["green"]=0.388,["blue"]=0.278,["alpha"]=1 },
    ["coral"]             = { ["red"]=1.000,["green"]=0.498,["blue"]=0.314,["alpha"]=1 },
    ["darkorange"]        = { ["red"]=1.000,["green"]=0.549,["blue"]=0.000,["alpha"]=1 },
    ["orange"]            = { ["red"]=1.000,["green"]=0.647,["blue"]=0.000,["alpha"]=1 },
-- Yellow colors
    ["yellow"]            = { ["red"]=1.000,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
    ["lightyellow"]       = { ["red"]=1.000,["green"]=1.000,["blue"]=0.878,["alpha"]=1 },
    ["lemonchiffon"]      = { ["red"]=1.000,["green"]=0.980,["blue"]=0.804,["alpha"]=1 },
    ["papayawhip"]        = { ["red"]=1.000,["green"]=0.937,["blue"]=0.835,["alpha"]=1 },
    ["moccasin"]          = { ["red"]=1.000,["green"]=0.894,["blue"]=0.710,["alpha"]=1 },
    ["peachpuff"]         = { ["red"]=1.000,["green"]=0.855,["blue"]=0.725,["alpha"]=1 },
    ["palegoldenrod"]     = { ["red"]=0.933,["green"]=0.910,["blue"]=0.667,["alpha"]=1 },
    ["khaki"]             = { ["red"]=0.941,["green"]=0.902,["blue"]=0.549,["alpha"]=1 },
    ["darkkhaki"]         = { ["red"]=0.741,["green"]=0.718,["blue"]=0.420,["alpha"]=1 },
    ["gold"]              = { ["red"]=1.000,["green"]=0.843,["blue"]=0.000,["alpha"]=1 },
-- Brown colors
    ["cornsilk"]          = { ["red"]=1.000,["green"]=0.973,["blue"]=0.863,["alpha"]=1 },
    ["blanchedalmond"]    = { ["red"]=1.000,["green"]=0.922,["blue"]=0.804,["alpha"]=1 },
    ["bisque"]            = { ["red"]=1.000,["green"]=0.894,["blue"]=0.769,["alpha"]=1 },
    ["navajowhite"]       = { ["red"]=1.000,["green"]=0.871,["blue"]=0.678,["alpha"]=1 },
    ["wheat"]             = { ["red"]=0.961,["green"]=0.871,["blue"]=0.702,["alpha"]=1 },
    ["burlywood"]         = { ["red"]=0.871,["green"]=0.722,["blue"]=0.529,["alpha"]=1 },
    ["tan"]               = { ["red"]=0.824,["green"]=0.706,["blue"]=0.549,["alpha"]=1 },
    ["rosybrown"]         = { ["red"]=0.737,["green"]=0.561,["blue"]=0.561,["alpha"]=1 },
    ["sandybrown"]        = { ["red"]=0.957,["green"]=0.643,["blue"]=0.376,["alpha"]=1 },
    ["goldenrod"]         = { ["red"]=0.855,["green"]=0.647,["blue"]=0.125,["alpha"]=1 },
    ["darkgoldenrod"]     = { ["red"]=0.722,["green"]=0.525,["blue"]=0.043,["alpha"]=1 },
    ["peru"]              = { ["red"]=0.804,["green"]=0.522,["blue"]=0.247,["alpha"]=1 },
    ["chocolate"]         = { ["red"]=0.824,["green"]=0.412,["blue"]=0.118,["alpha"]=1 },
    ["saddlebrown"]       = { ["red"]=0.545,["green"]=0.271,["blue"]=0.075,["alpha"]=1 },
    ["sienna"]            = { ["red"]=0.627,["green"]=0.322,["blue"]=0.176,["alpha"]=1 },
    ["brown"]             = { ["red"]=0.647,["green"]=0.165,["blue"]=0.165,["alpha"]=1 },
    ["maroon"]            = { ["red"]=0.502,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
-- Green colors
    ["darkolivegreen"]    = { ["red"]=0.333,["green"]=0.420,["blue"]=0.184,["alpha"]=1 },
    ["olive"]             = { ["red"]=0.502,["green"]=0.502,["blue"]=0.000,["alpha"]=1 },
    ["olivedrab"]         = { ["red"]=0.420,["green"]=0.557,["blue"]=0.137,["alpha"]=1 },
    ["yellowgreen"]       = { ["red"]=0.604,["green"]=0.804,["blue"]=0.196,["alpha"]=1 },
    ["limegreen"]         = { ["red"]=0.196,["green"]=0.804,["blue"]=0.196,["alpha"]=1 },
    ["lime"]              = { ["red"]=0.000,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
    ["lawngreen"]         = { ["red"]=0.486,["green"]=0.988,["blue"]=0.000,["alpha"]=1 },
    ["chartreuse"]        = { ["red"]=0.498,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
    ["greenyellow"]       = { ["red"]=0.678,["green"]=1.000,["blue"]=0.184,["alpha"]=1 },
    ["springgreen"]       = { ["red"]=0.000,["green"]=1.000,["blue"]=0.498,["alpha"]=1 },
    ["mediumspringgreen"] = { ["red"]=0.000,["green"]=0.980,["blue"]=0.604,["alpha"]=1 },
    ["lightgreen"]        = { ["red"]=0.565,["green"]=0.933,["blue"]=0.565,["alpha"]=1 },
    ["palegreen"]         = { ["red"]=0.596,["green"]=0.984,["blue"]=0.596,["alpha"]=1 },
    ["darkseagreen"]      = { ["red"]=0.561,["green"]=0.737,["blue"]=0.561,["alpha"]=1 },
    ["mediumseagreen"]    = { ["red"]=0.235,["green"]=0.702,["blue"]=0.443,["alpha"]=1 },
    ["seagreen"]          = { ["red"]=0.180,["green"]=0.545,["blue"]=0.341,["alpha"]=1 },
    ["forestgreen"]       = { ["red"]=0.133,["green"]=0.545,["blue"]=0.133,["alpha"]=1 },
    ["green"]             = { ["red"]=0.000,["green"]=0.502,["blue"]=0.000,["alpha"]=1 },
    ["darkgreen"]         = { ["red"]=0.000,["green"]=0.392,["blue"]=0.000,["alpha"]=1 },
-- Cyan colors
    ["mediumaquamarine"]  = { ["red"]=0.400,["green"]=0.804,["blue"]=0.667,["alpha"]=1 },
    ["aqua"]              = { ["red"]=0.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
    ["cyan"]              = { ["red"]=0.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
    ["lightcyan"]         = { ["red"]=0.878,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
    ["paleturquoise"]     = { ["red"]=0.686,["green"]=0.933,["blue"]=0.933,["alpha"]=1 },
    ["aquamarine"]        = { ["red"]=0.498,["green"]=1.000,["blue"]=0.831,["alpha"]=1 },
    ["turquoise"]         = { ["red"]=0.251,["green"]=0.878,["blue"]=0.816,["alpha"]=1 },
    ["mediumturquoise"]   = { ["red"]=0.282,["green"]=0.820,["blue"]=0.800,["alpha"]=1 },
    ["darkturquoise"]     = { ["red"]=0.000,["green"]=0.808,["blue"]=0.820,["alpha"]=1 },
    ["lightseagreen"]     = { ["red"]=0.125,["green"]=0.698,["blue"]=0.667,["alpha"]=1 },
    ["cadetblue"]         = { ["red"]=0.373,["green"]=0.620,["blue"]=0.627,["alpha"]=1 },
    ["darkcyan"]          = { ["red"]=0.000,["green"]=0.545,["blue"]=0.545,["alpha"]=1 },
    ["teal"]              = { ["red"]=0.000,["green"]=0.502,["blue"]=0.502,["alpha"]=1 },
-- Blue colors
    ["lightsteelblue"]    = { ["red"]=0.690,["green"]=0.769,["blue"]=0.871,["alpha"]=1 },
    ["powderblue"]        = { ["red"]=0.690,["green"]=0.878,["blue"]=0.902,["alpha"]=1 },
    ["lightblue"]         = { ["red"]=0.678,["green"]=0.847,["blue"]=0.902,["alpha"]=1 },
    ["skyblue"]           = { ["red"]=0.529,["green"]=0.808,["blue"]=0.922,["alpha"]=1 },
    ["lightskyblue"]      = { ["red"]=0.529,["green"]=0.808,["blue"]=0.980,["alpha"]=1 },
    ["deepskyblue"]       = { ["red"]=0.000,["green"]=0.749,["blue"]=1.000,["alpha"]=1 },
    ["dodgerblue"]        = { ["red"]=0.118,["green"]=0.565,["blue"]=1.000,["alpha"]=1 },
    ["cornflowerblue"]    = { ["red"]=0.392,["green"]=0.584,["blue"]=0.929,["alpha"]=1 },
    ["steelblue"]         = { ["red"]=0.275,["green"]=0.510,["blue"]=0.706,["alpha"]=1 },
    ["royalblue"]         = { ["red"]=0.255,["green"]=0.412,["blue"]=0.882,["alpha"]=1 },
    ["blue"]              = { ["red"]=0.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
    ["mediumblue"]        = { ["red"]=0.000,["green"]=0.000,["blue"]=0.804,["alpha"]=1 },
    ["darkblue"]          = { ["red"]=0.000,["green"]=0.000,["blue"]=0.545,["alpha"]=1 },
    ["navy"]              = { ["red"]=0.000,["green"]=0.000,["blue"]=0.502,["alpha"]=1 },
    ["midnightblue"]      = { ["red"]=0.098,["green"]=0.098,["blue"]=0.439,["alpha"]=1 },
-- Purple/Violet/Magenta colors
    ["lavender"]          = { ["red"]=0.902,["green"]=0.902,["blue"]=0.980,["alpha"]=1 },
    ["thistle"]           = { ["red"]=0.847,["green"]=0.749,["blue"]=0.847,["alpha"]=1 },
    ["plum"]              = { ["red"]=0.867,["green"]=0.627,["blue"]=0.867,["alpha"]=1 },
    ["violet"]            = { ["red"]=0.933,["green"]=0.510,["blue"]=0.933,["alpha"]=1 },
    ["orchid"]            = { ["red"]=0.855,["green"]=0.439,["blue"]=0.839,["alpha"]=1 },
    ["fuchsia"]           = { ["red"]=1.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
    ["magenta"]           = { ["red"]=1.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
    ["mediumorchid"]      = { ["red"]=0.729,["green"]=0.333,["blue"]=0.827,["alpha"]=1 },
    ["mediumpurple"]      = { ["red"]=0.576,["green"]=0.439,["blue"]=0.859,["alpha"]=1 },
    ["blueviolet"]        = { ["red"]=0.541,["green"]=0.169,["blue"]=0.886,["alpha"]=1 },
    ["darkviolet"]        = { ["red"]=0.580,["green"]=0.000,["blue"]=0.827,["alpha"]=1 },
    ["darkorchid"]        = { ["red"]=0.600,["green"]=0.196,["blue"]=0.800,["alpha"]=1 },
    ["darkmagenta"]       = { ["red"]=0.545,["green"]=0.000,["blue"]=0.545,["alpha"]=1 },
    ["purple"]            = { ["red"]=0.502,["green"]=0.000,["blue"]=0.502,["alpha"]=1 },
    ["indigo"]            = { ["red"]=0.294,["green"]=0.000,["blue"]=0.510,["alpha"]=1 },
    ["darkslateblue"]     = { ["red"]=0.282,["green"]=0.239,["blue"]=0.545,["alpha"]=1 },
    ["rebeccapurple"]     = { ["red"]=0.400,["green"]=0.200,["blue"]=0.600,["alpha"]=1 },
    ["slateblue"]         = { ["red"]=0.416,["green"]=0.353,["blue"]=0.804,["alpha"]=1 },
    ["mediumslateblue"]   = { ["red"]=0.482,["green"]=0.408,["blue"]=0.933,["alpha"]=1 },
-- White colors
    ["white"]             = { ["red"]=1.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
    ["snow"]              = { ["red"]=1.000,["green"]=0.980,["blue"]=0.980,["alpha"]=1 },
    ["honeydew"]          = { ["red"]=0.941,["green"]=1.000,["blue"]=0.941,["alpha"]=1 },
    ["mintcream"]         = { ["red"]=0.961,["green"]=1.000,["blue"]=0.980,["alpha"]=1 },
    ["azure"]             = { ["red"]=0.941,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
    ["aliceblue"]         = { ["red"]=0.941,["green"]=0.973,["blue"]=1.000,["alpha"]=1 },
    ["ghostwhite"]        = { ["red"]=0.973,["green"]=0.973,["blue"]=1.000,["alpha"]=1 },
    ["whitesmoke"]        = { ["red"]=0.961,["green"]=0.961,["blue"]=0.961,["alpha"]=1 },
    ["seashell"]          = { ["red"]=1.000,["green"]=0.961,["blue"]=0.933,["alpha"]=1 },
    ["beige"]             = { ["red"]=0.961,["green"]=0.961,["blue"]=0.863,["alpha"]=1 },
    ["oldlace"]           = { ["red"]=0.992,["green"]=0.961,["blue"]=0.902,["alpha"]=1 },
    ["floralwhite"]       = { ["red"]=1.000,["green"]=0.980,["blue"]=0.941,["alpha"]=1 },
    ["ivory"]             = { ["red"]=1.000,["green"]=1.000,["blue"]=0.941,["alpha"]=1 },
    ["antiquewhite"]      = { ["red"]=0.980,["green"]=0.922,["blue"]=0.843,["alpha"]=1 },
    ["linen"]             = { ["red"]=0.980,["green"]=0.941,["blue"]=0.902,["alpha"]=1 },
    ["lavenderblush"]     = { ["red"]=1.000,["green"]=0.941,["blue"]=0.961,["alpha"]=1 },
    ["mistyrose"]         = { ["red"]=1.000,["green"]=0.894,["blue"]=0.882,["alpha"]=1 },
-- Gray/Black colors
    ["gainsboro"]         = { ["red"]=0.863,["green"]=0.863,["blue"]=0.863,["alpha"]=1 },
    ["lightgrey"]         = { ["red"]=0.827,["green"]=0.827,["blue"]=0.827,["alpha"]=1 },
    ["silver"]            = { ["red"]=0.753,["green"]=0.753,["blue"]=0.753,["alpha"]=1 },
    ["darkgray"]          = { ["red"]=0.663,["green"]=0.663,["blue"]=0.663,["alpha"]=1 },
    ["gray"]              = { ["red"]=0.502,["green"]=0.502,["blue"]=0.502,["alpha"]=1 },
    ["dimgray"]           = { ["red"]=0.412,["green"]=0.412,["blue"]=0.412,["alpha"]=1 },
    ["lightslategray"]    = { ["red"]=0.467,["green"]=0.533,["blue"]=0.600,["alpha"]=1 },
    ["slategray"]         = { ["red"]=0.439,["green"]=0.502,["blue"]=0.565,["alpha"]=1 },
    ["darkslategray"]     = { ["red"]=0.184,["green"]=0.310,["blue"]=0.310,["alpha"]=1 },
    ["black"]             = { ["red"]=0.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
}

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

return module
