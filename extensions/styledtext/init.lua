--- === hs.styledtext ===
---
--- This module adds support for controlling the style of the text in Hammerspoon.

local module = require("hs.styledtext.internal")
require("hs.drawing.color") -- make sure that the conversion helpers required to support color are loaded

-- private variables and methods -----------------------------------------

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

local _arrayWrapper = function(results)
    return setmetatable(results, { __tostring=function(_)
        local results = ""
        for i,v in ipairs(_) do results = results..v.."\n" end
        return results
    end})
end

local _tableWrapper = function(results)
    local __tableWrapperFunction
    __tableWrapperFunction = function(_)
        local result = ""
        local width = 0
        for k,v in pairs(_) do width = width < #k and #k or width end
        for k,v in require("hs.fnutils").sortByKeys(_) do
            result = result..string.format("%-"..tostring(width).."s ", k)
            if type(v) == "table" then
                result = result..__tableWrapperFunction(v):gsub("[ \n]", {[" "] = "=", ["\n"] = " "}).."\n"
            else
                result = result..tostring(v).."\n"
            end
        end
        return result
    end

    return setmetatable(results, { __tostring=__tableWrapperFunction })
end

local internalFontFunctions = {
    fontNames           = module.fontNames,
    fontNamesWithTraits = module.fontNamesWithTraits,
    fontInfo            = module.fontInfo,
}

-- Public interface ------------------------------------------------------

-- tweak the hs.styledtext object metatable with things easier to do in lua...
local objectMetatable = hs.getObjectMetatable("hs.styledtext")
objectMetatable.byte   = function(self, ...) return self:asString():byte(...) end
objectMetatable.find   = function(self, ...) return self:asString():find(...) end
objectMetatable.match  = function(self, ...) return self:asString():match(...) end
objectMetatable.gmatch = function(self, ...) return self:asString():gmatch(...) end

objectMetatable.rep    = function(self, n, sep)
    if n < 1 then return module.new("") end
    local i, result = 1, self:copy()
    while (i < n) do
        if sep then result = result..sep end
        result = result..self
        i = i + 1
    end
    return result
end

-- string.format   is hs.styletext.new(string.format(...)) sufficient?
-- string.reverse  reversing styles, attachment anchors, etc. do not present an obvious solution...
-- string.gsub     replaces substrings internally... no obvious simple solution that maintains/supports styles...
-- string.char     hs.styledtext.new(string.char(...)) is more clear as to what's intended
-- string.dump     makes no sense in the context of styled strings
-- string.pack     makes no sense in the context of styled strings
-- string.packsize makes no sense in the context of styled strings
-- string.unpack   makes no sense in the context of styled strings

module.fontTraits    = _makeConstantsTable(module.fontTraits)
module.linePatterns  = _makeConstantsTable(module.linePatterns)
module.lineStyles    = _makeConstantsTable(module.lineStyles)
module.lineAppliesTo = _makeConstantsTable(module.lineAppliesTo)

module.fontNames = function(...)
    return _arrayWrapper(internalFontFunctions.fontNames(...))
end

module.fontNamesWithTraits = function(...)
    return _arrayWrapper(internalFontFunctions.fontNamesWithTraits(...))
end

module.fontInfo = function(...)
    return _tableWrapper(internalFontFunctions.fontInfo(...))
end

module.ansi = function(rawText, attr)
    local drawing    = require("hs.drawing")
    local color      = require("hs.drawing.color")

    local sgrCodeToAttributes = {
        [  0] = { adjustFontStyle    = "remove",
                  backgroundColor    = "remove",
                  color              = "remove",
                  underlineStyle     = "remove",
                  strikethroughStyle = "remove",
                },

        [  1] = { adjustFontStyle = true  }, -- increased intensity; generally bold, if the font isn't already
        [  2] = { adjustFontStyle = false }, -- fainter intensity; generally not available in fixed pitch fonts, but try
        [  3] = { adjustFontStyle = module.fontTraits.italicFont },
        [ 22] = { adjustFontStyle = "remove" },

        [  4] = { underlineStyle = module.lineStyles.single },
        [ 21] = { underlineStyle = module.lineStyles.double },
        [ 24] = { underlineStyle = module.lineStyles.none },

        [  9] = { strikethroughStyle = module.lineStyles.single },
        [ 29] = { strikethroughStyle = module.lineStyles.none },

        [ 30] = { color = color.colorsFor("ansiTerminalColors").fgBlack },
        [ 31] = { color = color.colorsFor("ansiTerminalColors").fgRed },
        [ 32] = { color = color.colorsFor("ansiTerminalColors").fgGreen },
        [ 33] = { color = color.colorsFor("ansiTerminalColors").fgYellow },
        [ 34] = { color = color.colorsFor("ansiTerminalColors").fgBlue },
        [ 35] = { color = color.colorsFor("ansiTerminalColors").fgMagenta },
        [ 36] = { color = color.colorsFor("ansiTerminalColors").fgCyan },
        [ 37] = { color = color.colorsFor("ansiTerminalColors").fgWhite },

    -- if we want to add more colors (not official ANSI, but somewhat supported):
    --       38;5;#m for 256 colors (supported in OSX Terminal and in xterm)
    --       38;2;#;#;#m for rgb color (not in Terminal, but is in xterm)
    --     [ 38] = { color = "special" },
        [ 39] = { color = "remove" },

        [ 90] = { color = color.colorsFor("ansiTerminalColors").fgBrightBlack },
        [ 91] = { color = color.colorsFor("ansiTerminalColors").fgBrightRed },
        [ 92] = { color = color.colorsFor("ansiTerminalColors").fgBrightGreen },
        [ 93] = { color = color.colorsFor("ansiTerminalColors").fgBrightYellow },
        [ 94] = { color = color.colorsFor("ansiTerminalColors").fgBrightBlue },
        [ 95] = { color = color.colorsFor("ansiTerminalColors").fgBrightMagenta },
        [ 96] = { color = color.colorsFor("ansiTerminalColors").fgBrightCyan },
        [ 97] = { color = color.colorsFor("ansiTerminalColors").fgBrightWhite },

        [ 40] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBlack },
        [ 41] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgRed },
        [ 42] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgGreen },
        [ 43] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgYellow },
        [ 44] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBlue },
        [ 45] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgMagenta },
        [ 46] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgCyan },
        [ 47] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgWhite },

    -- if we want to add more colors (not official ANSI, but somewhat supported):
    --       48;5;#m for 256 colors (supported in OSX Terminal and in xterm)
    --       48;2;#;#;#m for rgb color (not in Terminal, but is in xterm)
    --     [ 48] = { backgroundColor = "special" },
        [ 49] = { backgroundColor = "remove" },

        [100] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightBlack },
        [101] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightRed },
        [102] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightGreen },
        [103] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightYellow },
        [104] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightBlue },
        [105] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightMagenta },
        [106] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightCyan },
        [107] = { backgroundColor = color.colorsFor("ansiTerminalColors").bgBrightWhite },
    }

    assert(type(rawText) == "string", "string expected")

-- used for font bold and italic changes.
--    if no attr table is specified, assume the hs.drawing default font
--    if a table w/out font is specified, assume the NSAttributedString default (Helvetica at 12.0)
    local baseFont
    if type(attr) == "nil" then baseFont = drawing.defaultTextStyle().font end
    local baseFont = baseFont or (attr and attr.font) or { name = "Helvetica", size = 12.0 }

-- generate clean string and locate ANSI codes
    local cleanString = ""
    local formatCodes = {}
    local index = 1

    while true do
        local s, e = rawText:find("\27[", index, true) -- why does lua support inline decimal and inline hex but not inline octal for control characters?
        if s then
            local code, codes = 0, {}
            local incodeIndex = 1
            while true do
                local c = rawText:sub(e + incodeIndex, e + incodeIndex):byte()
                if 48 <= c and c <= 57 then       -- "0" - "9"
                    code = (code == 0) and (c - 48) or (code * 10 + (c - 48))
                elseif c == 109 then              -- "m", the terminator for SGR
                    table.insert(codes, code)
                    break
                elseif c == 59 then               -- ";" multi-code sequence separator
                    table.insert(codes, code)
                    code = 0
                elseif 64 <= c and c <= 126 then  -- other terminators indicate this is a sequence we ignore
                    codes = {}
                    break
                end
                incodeIndex = incodeIndex + 1
            end
            cleanString = cleanString .. rawText:sub(index, s - 1)
            if #codes > 0 then
                for i = 1, #codes, 1 do
                    table.insert(formatCodes, { #cleanString + 1, codes[i] })
                end
            end
            index = e + incodeIndex + 1
        else
            cleanString = cleanString .. rawText:sub(index)
            break
        end
    end

-- create base string with clean string and specified attributes, if any
    local newString = module.new(cleanString, attr or {})

-- iterate through codes and determine what style attributes to apply
    for i = 1, #formatCodes, 1 do
        local s, code = formatCodes[i][1], formatCodes[i][2]
        if code ~= 0 then                                             -- skip reset everything code
            local action = sgrCodeToAttributes[code]
            if action then                                            -- only do codes we recognize
               for k, v in pairs(action) do
                  if not(type(v) == "string" and v == "remove") then  -- skip placeholder to turn something off
                      local e, newAttribute = #cleanString, {} -- end defaults to the end of the string
-- scan for what turns us off
                      for j = i + 1, #formatCodes, 1 do
                          local nextAction =  sgrCodeToAttributes[formatCodes[j][2]]
                          if nextAction[k] then
                              e = formatCodes[j][1] - 1 -- adjust the actual end point since something later resets it
                              break
                          end
                      end
-- NOTE:  If support for 256 and/or RGB color is added, remember to adjust i here because we'll actually need to use
--        multiple entries in formatCodes to determine which color was specified.
-- apply the style now that we have an end point
                      if k == "adjustFontStyle" then
                          newAttribute.font = module.convertFont(baseFont, v)
                      else
                          newAttribute[k] = v
                      end
                      newString = newString:setStyle(newAttribute, s, e)
                  end
               end
            end
        end
    end

    return newString
end

-- Return Module Object --------------------------------------------------

return module
