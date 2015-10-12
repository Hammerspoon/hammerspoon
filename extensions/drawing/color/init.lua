local module = require("hs.drawing.color.internal")

--- === hs.drawing.color ===
---
--- Additions to hs.drawing which provide access to the system color lists and a wider variety of ways to represent color within Hammerspoon.
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
--- * From the system color lists:
---   * list - the name of the system color list
---   * name - the color name within the specified color list
---
--- Any combination of the above keys may be specified within the color table and they will be evaluated in the following order:
---   1. If the `list` and `name` keys are specified, and if they can be matched to an existing color within the system color lists, that color is used.
---   2. If the `hue` key is provided, then the color is generated as an HSB color
---   3. If the `white` key is provided, then the color is generated as a Grayscale color
---   4. Otherwise, an RGB color is generated.
---
--- Except where specified above to indicate the color model being used, any key which is not provided defaults to a value of 0.0, except for `alpha`, which defaults to 1.0.  This means that specifying an empty table as the color will result in an opaque black color.


-- doc defined in internal.m
local internalColorLists = module.lists
module.lists = function(...)
    local interimValue = internalColorLists(...)
    for k, v in pairs(module.moduleDefinedLists) do interimValue[k] = v end
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
--- A collection of colors representing the ANSI Terminal color sequences.  The color definitions are based upon code found at https://github.com/balthamos/geektool-3/blob/ac91b2d03c4f6002b007695f5b0ce73514eb291f/NerdTool/classes/ANSIEscapeHelper.m.
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


--- hs.drawing.color.hammerspoon
--- Variable
--- This table contains a collection of various useful pre-defined colors:
---  * osx_red - The same red used for OS X window close buttons
---  * osx_green - The same green used for OS X window zoom buttons
---  * osx_yellow - The same yellow used for OS X window minimize buttons
---
--- Notes:
--- * Previous versions of Hammerspoon included these colors at the `hs.drawing.color` path; for backwards compatibility, the keys of this table are replicated at that path as long as they do not conflict with any other color collection or function within the `hs.drawing.color` module.

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

-- to allow hs.drawing.color.lists and hs.drawing.color.colorsFor to include these in the "system" lists,
-- keep this up to date with any collection additions
module.moduleDefinedLists = {
    hammerspoon        = module.hammerspoon,
    ansiTerminalColors = module.ansiTerminalColors
}

return module