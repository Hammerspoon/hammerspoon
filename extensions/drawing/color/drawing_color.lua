local module = require("hs.libdrawing_color")

--- === hs.drawing.color ===
---
--- Provides ccess to the system color lists and a wider variety of ways to represent color within Hammerspoon.
---
--- Color is represented within Hammerspoon as a table containing keys which tell Hammerspoon how the color is specified.  You can specify a color in one of the following ways, depending upon the keys you supply within the table:
---
--- * As a combination of Red, Green, and Blue elements (RGB Color):
---   * red   - the red component of the color specified as a number from 0.0 to 1.0.
---   * green - the green component of the color specified as a number from 0.0 to 1.0.
---   * blue  - the blue component of the color specified as a number from 0.0 to 1.0.
---   * alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * As a combination of Hue, Saturation, and Brightness (HSB or HSV Color):
---   * hue        - the hue component of the color specified as a number from 0.0 to 1.0.
---   * saturation - the saturation component of the color specified as a number from 0.0 to 1.0.
---   * brightness - the brightness component of the color specified as a number from 0.0 to 1.0.
---   * alpha      - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * As grayscale (Grayscale Color):
---   * white - the ratio of white to black from 0.0 (completely black) to 1.0 (completely white)
---   * alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * From the system or Hammerspoon color lists:
---   * list - the name of a system color list or a collection list defined in `hs.drawing.color`
---   * name - the color name within the specified color list
---
--- * As an HTML style hex color specification:
---   * hex   - a string of the format "#rrggbb" or "#rgb" where `r`, `g`, and `b` are hexadecimal digits (i.e. 0-9, A-F)
---   * alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * From an image to be used as a tiled pattern:
---   * image - an `hs.image` object representing the image to be used as a tiled pattern
---
--- Any combination of the above keys may be specified within the color table and they will be evaluated in the following order:
---   1. if the `image` key is specified, it will be used to create a tiling pattern.
---   2. If the `list` and `name` keys are specified, and if they can be matched to an existing color within the system color lists, that color is used.
---   3. If the `hue` key is provided, then the color is generated as an HSB color
---   4. If the `white` key is provided, then the color is generated as a Grayscale color
---   5. Otherwise, an RGB color is generated.
---
--- Except where specified above to indicate the color model being used, any key which is not provided defaults to a value of 0.0, except for `alpha`, which defaults to 1.0.  This means that specifying an empty table as the color will result in an opaque black color.

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
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..k.."\n"
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

-- we don't use the one in LuaSkin because it recurses through subtables and we want to leave those editable so users
-- can apply local overrides if desired
local _singleLevelConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    return results
end


-- doc defined in internal.m
local internalColorLists = module.lists
module.lists = function(...)
    local interimValue = internalColorLists(...)
    for k, v in pairs(module.definedCollections) do interimValue[k] = v end
    return setmetatable(interimValue, {
        __tostring = function(_)
            local fnutils, result = require("hs.fnutils"), ""
            for k, v in fnutils.sortByKeys(_) do result = result..k.."\n" end
            return result
        end
    })
end

--- hs.drawing.color.colorsFor(list) -> table
--- Function
--- Returns a table containing the colors for the specified system color list or hs.drawing.color collection.
---
--- Parameters:
---  * list - the name of the list to provide colors for
---
--- Returns:
---  * a table whose keys are made from the colors provided by the color list or nil if the list does not exist.
---
--- Notes:
---  * Where possible, each color node is provided as its RGB color representation.  Where this is not possible, the color node contains the keys `list` and `name` which identify the indicated color.  This means that you can use the following wherever a color parameter is expected: `hs.drawing.color.colorsFor(list)["color-name"]`
---  * This function provides a tostring metatable method which allows listing the defined colors in the list in the Hammerspoon console with: `hs.drawing.colorsFor(list)`
---  * See also `hs.drawing.color.lists`
module.colorsFor = function(list, ...)
    local interimValue = module.lists(...)[list]
    if interimValue then
        return setmetatable(interimValue, {
            __tostring = function(_)
                local fnutils, result = require("hs.fnutils"), ""
                for k, v in fnutils.sortByKeys(_) do result = result..k.."\n" end
                return result
            end
        })
    else
        return nil
    end
end

--- hs.drawing.color.ansiTerminalColors
--- Variable
--- A collection of colors representing the ANSI Terminal color sequences.  The color definitions are based upon code found at https://github.com/balthamos/geektool-3 in the /NerdTool/classes/ANSIEscapeHelper.m file.
---
--- Notes:
---  * This is not a constant, so you can adjust the colors at run time for your installation if desired.
module.ansiTerminalColors = {
    fgBlack         = { list = "Apple", name = "Black" },
    fgRed           = { list = "Apple", name = "Red" },
    fgGreen         = { list = "Apple", name = "Green" },
    fgYellow        = { list = "Apple", name = "Yellow" },
    fgBlue          = { list = "Apple", name = "Blue" },
    fgMagenta       = { list = "Apple", name = "Magenta" },
    fgCyan          = { list = "Apple", name = "Cyan" },
    fgWhite         = { list = "Apple", name = "White" },
    fgBrightBlack   = { white = 0.337, alpha = 1 },
    fgBrightRed     = { hue = 1,     saturation = 0.4, brightness = 1, alpha = 1},
    fgBrightGreen   = { hue = 1/3,   saturation = 0.4, brightness = 1, alpha = 1},
    fgBrightYellow  = { hue = 1/6,   saturation = 0.4, brightness = 1, alpha = 1},
    fgBrightBlue    = { hue = 2/3,   saturation = 0.4, brightness = 1, alpha = 1},
    fgBrightMagenta = { hue = 5/6,   saturation = 0.4, brightness = 1, alpha = 1},
    fgBrightCyan    = { hue = 0.5,   saturation = 0.4, brightness = 1, alpha = 1},
    fgBrightWhite   = { list = "Apple", name = "White" },
    bgBlack         = { list = "Apple", name = "Black" },
    bgRed           = { list = "Apple", name = "Red" },
    bgGreen         = { list = "Apple", name = "Green" },
    bgYellow        = { list = "Apple", name = "Yellow" },
    bgBlue          = { list = "Apple", name = "Blue" },
    bgMagenta       = { list = "Apple", name = "Magenta" },
    bgCyan          = { list = "Apple", name = "Cyan" },
    bgWhite         = { list = "Apple", name = "White" },
    bgBrightBlack   = { white = 0.337, alpha = 1 },
    bgBrightRed     = { hue = 1,     saturation = 0.4, brightness = 1, alpha = 1},
    bgBrightGreen   = { hue = 1/3,   saturation = 0.4, brightness = 1, alpha = 1},
    bgBrightYellow  = { hue = 1/6,   saturation = 0.4, brightness = 1, alpha = 1},
    bgBrightBlue    = { hue = 2/3,   saturation = 0.4, brightness = 1, alpha = 1},
    bgBrightMagenta = { hue = 5/6,   saturation = 0.4, brightness = 1, alpha = 1},
    bgBrightCyan    = { hue = 0.5,   saturation = 0.4, brightness = 1, alpha = 1},
    bgBrightWhite   = { list = "Apple", name = "White" },
}

--- hs.drawing.color.x11
--- Variable
--- A collection of colors representing the X11 color names as defined at  https://en.wikipedia.org/wiki/Web_colors#X11_color_names (names in lowercase)
---
--- Notes:
---  * This is not a constant, so you can adjust the colors at run time for your installation if desired.
module.x11 = {
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

--- hs.drawing.color.hammerspoon
--- Variable
--- This table contains a collection of various useful pre-defined colors:
---  * osx_red - The same red used for OS X window close buttons
---  * osx_green - The same green used for OS X window zoom buttons
---  * osx_yellow - The same yellow used for OS X window minimize buttons
---
--- Notes:
---  * This is not a constant, so you can adjust the colors at run time for your installation if desired.
---
---  * Previous versions of Hammerspoon included these colors at the `hs.drawing.color` path; for backwards compatibility, the keys of this table are replicated at that path as long as they do not conflict with any other color collection or function within the `hs.drawing.color` module.  You really should adjust your code to use the collection, as this may change in the future.
module.hammerspoon =  {
    ["osx_green"]   = { ["red"]=0.153,["green"]=0.788,["blue"]=0.251,["alpha"]=1 },
    ["osx_red"]     = { ["red"]=0.996,["green"]=0.329,["blue"]=0.302,["alpha"]=1 },
    ["osx_yellow"]  = { ["red"]=1.000,["green"]=0.741,["blue"]=0.180,["alpha"]=1 },
    ["red"]         = { ["red"]=1.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
    ["green"]       = { ["red"]=0.000,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
    ["blue"]        = { ["red"]=0.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
    ["white"]       = { ["red"]=1.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
    ["black"]       = { ["red"]=0.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
}

-- NOTE: Make this last to ensure it doesn't cause collisions with other collections or functions
for k,v in pairs(module.hammerspoon) do
    if module[k] then
        print("++ hs.drawing.color."..tostring(k).." already exists -- skiping deprecated color path duplication for this color")
    else
        module[k] = v
    end
end

--- hs.drawing.color.definedCollections
--- Constant
--- This table contains this list of defined color collections provided by the `hs.drawing.color` module.  Collections differ from the system color lists in that you can modify the color values their members contain by modifying the table at `hs.drawing.color.<collection>.<color>` and future references to that color will reflect the new changes, thus allowing you to customize the palettes for your installation.
---
--- Notes:
---  * This list is a constant, but the members it refers to are not.
module.definedCollections = _singleLevelConstantsTable({

-- NOTE: to allow hs.drawing.color.lists, hs.drawing.color.colorsFor, and the
-- LuaSkin convertor for NSColor to support collections, keep this up to date
-- with any collection additions

    hammerspoon        = module.hammerspoon,
    ansiTerminalColors = module.ansiTerminalColors,
    x11                = module.x11,
})

if (module.definedCollections) then
    module._registerColorCollectionsTable(module.definedCollections)
    module._registerColorCollectionsTable = nil -- no need to keep this function around
end

return module
