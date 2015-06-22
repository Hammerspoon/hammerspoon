--- === hs.utf8_53 ===
---
--- Functions providing basic support for UTF-8 encodings
---
--- For Hammerspoon versions running with the Lua 5.2 core, this module will include a compatibility library to provide the same functionality as the Lua 5.3.1 utf8 library. For Hammerspoon versions running with the Lua 5.3 core, this compatibility library is left out, but a metatable index will pass through the same function names directly to the builtin Lua 5.3 utf8 library, allowing code which relies on these functions to work in either environment.  The additional functions providing codepoint to UTF8 sequence conversion and the registering of labels for common codepoints is provided in both environments.
---
--- Compatibility library notes:
---
--- These functions are from the UTF-8 Library as provided by the [Lua 5.3.1 programming language](http://www.lua.org/). This is primarily this a wrapper to allow easy inclusion within the Hammerspoon environment.
---
--- The following text is from the [reference documentation](http://www.lua.org/docs.html) for the Lua 5.3.1 programming language.
---
--- > This library provides basic support for UTF-8 encoding. It provides all its functions inside the table utf8. This library does not provide any support for Unicode other than the handling of the encoding. Any operation that needs the meaning of a character, such as character classification, is outside its scope.
--- >
--- > Unless stated otherwise, all functions that expect a byte position as a parameter assume that the given position is either the start of a byte sequence or one plus the length of the subject string. As in the string library, negative indices count from the end of the string.
---
--- ### Notes
--- Hydra provided two UTF-8 functions which can be replicated by this module.
---
--- For `hydra.utf8.count(str)` use `utf8_53.len(str)`
---
--- For `hydra.utf8.chars(str)`, which provided an array of the individual UTF-8 characters of `str`, use the following:
---
---     t = {} ; str:gsub(utf8_53.charPattern, function(c) t[#t+1] = c end)
---

--- hs.utf8_53.char(...) -> string
--- Function
--- Receives zero or more integers, converts each one to its corresponding UTF-8 byte sequence and returns a string with the concatenation of all these sequences.
---
--- Notes:
---  * This function is ported from the Lua 5.3.1 source code.

--- hs.utf8_53.codes(s) -> position, codepoint
--- Function
--- Returns values so that the construction
---
---      for p, c in utf8.codes(s) do body end
---
--- will iterate over all characters in string s, with p being the position (in bytes) and c the code point of each character. It raises an error if it meets any invalid byte sequence.
---
--- Notes:
---  * This function is ported from the Lua 5.3.1 source code.

--- hs.utf8_53.codepoint(s [, i [, j]]) -> codepoint[, ...]
--- Function
--- Returns the codepoints (as integers) from all characters in s that start between byte position i and j (both included). The default for i is 1 and for j is i. It raises an error if it meets any invalid byte sequence.
---
--- Notes:
---  * This function is ported from the Lua 5.3.1 source code.

--- hs.utf8_53.len(s [, i [, j]]) -> count | nil, position
--- Function
--- Returns the number of UTF-8 characters in string s that start between positions i and @{j} (both inclusive). The default for i is 1 and for j is -1. If it finds any invalid byte sequence, returns nil plus the position of the first invalid byte.
---
--- Notes:
---  * This function is ported from the Lua 5.3.1 source code.

--- hs.utf8_53.offset(s, n [, i]) -> position
--- Function
--- Returns the position (in bytes) where the encoding of the n-th character of s (counting from position i) starts. A negative n gets characters before position i. The default for i is 1 when n is non-negative and #s + 1 otherwise, so that utf8.offset(s, -n) gets the offset of the n-th character from the end of the string. If the specified character is not in the subject or right after its end, the function returns nil.
--- As a special case, when n is 0 the function returns the start of the encoding of the character that contains the i-th byte of s.
---
--- This function assumes that s is a valid UTF-8 string.
---
--- Notes:
---  * This function is ported from the Lua 5.3.1 source code.

--- hs.utf8_53.charPattern
--- Variable
---The pattern (a string, not a function) "[\0-\x7F\xC2-\xF4][\x80-\xBF]*" (see 6.4.1 in [reference documentation](http://www.lua.org/docs.html)), which matches exactly one UTF-8 byte sequence, assuming that the subject is a valid UTF-8 string.
---
--- Notes:
---  * This variable is ported from the Lua 5.3.1 source code.

local module = {}
if string.match(_VERSION,"5.3") then
    module = setmetatable(module, {
        __index = function(object, key)
            for i,v in pairs(_G.utf8) do
                if string.lower(key) == i then return v end
            end
            return nil
        end
    })
else
    print("-- loading utf8_53 compatibility library")
    module = require("hs.utf8_53.internal-utf8")
end

local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.utf8_53.codepointToUTF8(codepoint) -> string
--- Function
--- Returns the string of bytes which represent the UTF-8 encoding of the provided codepoint.
---
--- Parameters:
---  * codepoint -- The Unicode code point to be converted to a UTF-8 byte sequence.
---
--- Returns:
---  * A string containing the UTF-8 byte sequence corresponding to provided codepoint.
---
--- Notes:
---  * This function is *NOT* part of the Lua 5.3.1 source code, and is provided for convenience within Hammerspoon.
---  * Code adapted from code sample found at https://en.wikipedia.org/wiki/UTF-8
---  * Valid codepoint values are from 0x0000 - 0x10FFFF (0 - 1114111)
---  * If the codepoint provided is a string that starts with U+, then the 'U+' is converted to a '0x' so that lua can properly treat the value as numeric.
---  * Invalid codepoints are returned as the Unicode Replacement Character (U+FFFD)
---    * This includes out of range codepoints as well as the Unicode Surrogate codepoints (U+D800 - U+DFFF)
module.codepointToUTF8 = function(codepoint)
    if type(codepoint) == "string" then codepoint = codepoint:gsub("^U%+","0x") end
    codepoint = tonumber(codepoint)

    -- negatives not allowed
    if codepoint < 0 then return module.generateUTF8Character(0xFFFD) end

    -- the surrogates cause print() to crash -- and they're invalid UTF-8 anyways
    if codepoint >= 0xD800 and codepoint <=0xDFFF then return module.generateUTF8Character(0xFFFD) end

    if string.match(_VERSION,"5.3") then
        if codepoint < 0x80          then
            return  string.char(codepoint)
        elseif codepoint <= 0x7FF    then
            return  string.char(( codepoint >>  6)         + 0xC0)..
                    string.char((        codepoint & 0x3F) + 0x80)
        elseif codepoint <= 0xFFFF   then
            return  string.char(( codepoint >> 12)         + 0xE0)..
                    string.char(((codepoint >>  6) & 0x3F) + 0x80)..
                    string.char((        codepoint & 0x3F) + 0x80)
        elseif codepoint <= 0x10FFFF then
            return  string.char(( codepoint >> 18)         + 0xF0)..
                    string.char(((codepoint >> 12) & 0x3F) + 0x80)..
                    string.char(((codepoint >>  6) & 0x3F) + 0x80)..
                    string.char((        codepoint & 0x3F) + 0x80)
        end
    else
        if codepoint < 0x80          then
            return  string.char(codepoint)
        elseif codepoint <= 0x7FF    then
            return  string.char(           bit32.rshift(codepoint,  6)        + 0xC0)..
                    string.char(bit32.band(             codepoint, 0x3F)      + 0x80)
        elseif codepoint <= 0xFFFF   then
            return  string.char(           bit32.rshift(codepoint, 12)        + 0xE0)..
                    string.char(bit32.band(bit32.rshift(codepoint,  6), 0x3F) + 0x80)..
                    string.char(bit32.band(             codepoint, 0x3F)      + 0x80)
        elseif codepoint <= 0x10FFFF then
            return  string.char(           bit32.rshift(codepoint, 18)        + 0xF0)..
                    string.char(bit32.band(bit32.rshift(codepoint, 12), 0x3F) + 0x80)..
                    string.char(bit32.band(bit32.rshift(codepoint,  6), 0x3F) + 0x80)..
                    string.char(bit32.band(             codepoint, 0x3F)      + 0x80)
        end
    end

    -- greater than 0x10FFFF is invalid UTF-8
    return module.generateUTF8Character(0xFFFD)
end

-- see below -- we need it defined for the registration function, but documentation will be
-- given where we add the predefined keys.
module.registeredKeys = setmetatable({}, { __tostring = function(object)
            local output = ""
            for i,v in fnutils.sortByKeys(object) do
                output = output..string.format("(U+%04X) %-15s  %s\n", module.codepoint(v), i, v)
            end
            return output
    end
})

--- hs.utf8_53.registerCodepoint(label, codepoint) -> string
--- Function
--- Registers a Unicode codepoint under the given label as a UTF-8 string of bytes which can be referenced by the label later in your code as `hs.utf8_53.registeredKeys[label]` for convenience and readability.
---
--- Parameters:
---  * label -- a string label to use as a human-readable reference when getting the UTF-8 byte sequence for use in other strings and output functions.
---  * codepoint -- a Unicode codepoint in numeric or `U+xxxx` format to register with the given label.
---
--- Returns:
---  * Returns the UTF-8 byte sequence for the Unicode codepoint registered.
---
--- Notes:
--- Notes:
---  * This function is *NOT* part of the Lua 5.3.1 source code, and is provided for convenience within Hammerspoon.
---  * If a codepoint label was previously registered, this will overwrite the previous value with a new one.  Because many of the special keys you may want to register have different variants, this allows you to easily modify the existing predefined defaults to suite your preferences.
---  * The return value is merely syntactic sugar and you do not need to save it locally; it can be safely ignored -- future access to the pre-converted codepoint should be retrieved as `hs.utf8_53.registeredKeys[label]` in your code.  It looks good when invoked from the console, though ☺.
module.registerCodepoint = function(label, codepoint)
    module.registeredKeys[label] = module.codepointToUTF8(codepoint)
    return module.registeredKeys[label]
end

--- hs.utf8_53.registeredKeys[]
--- Variable
--- A collection of UTF-8 characters already converted from codepoint and available as convient key-value pairs.  UTF-8 printable versions of common Apple and OS X special keys are predefined and others can be added with `hs.utf8_53.registerCodepoint(label, codepoint)` for your own use.
---
--- Predefined keys include:
---
---     (U+2325) alt              ⌥
---     (U+F8FF) apple            
---     (U+21E4) backtab          ⇤
---     (U+21EA) capslock         ⇪
---     (U+2713) checkMark        ✓
---     (U+2318) cmd              ⌘
---     (U+00A9) copyrightSign    ©
---     (U+2303) ctrl             ⌃
---     (U+232B) delete           ⌫
---     (U+2193) down             ↓
---     (U+21E3) down2            ⇣
---     (U+23CF) eject            ⏏
---     (U+21F2) end              ⇲
---     (U+2198) end2             ↘
---     (U+238B) escape           ⎋
---     (U+2326) forwarddelete    ⌦
---     (U+FE56) help             ﹖
---     (U+21F1) home             ⇱
---     (U+2196) home2            ↖
---     (U+21B8) home3            ↸
---     (U+2190) left             ←
---     (U+21E0) left2            ⇠
---     (U+201C) leftDoubleQuote  “
---     (U+2018) leftSingleQuote  ‘
---     (U+00B7) middleDot        ·
---     (U+21ED) numlock          ⇭
---     (U+2325) option           ⌥
---     (U+2327) padclear         ⌧
---     (U+2324) padenter         ⌤
---     (U+2386) padenter2        ⎆
---     (U+21A9) padenter3        ↩
---     (U+21DF) pagedown         ⇟
---     (U+21DE) pageup           ⇞
---     (U+233D) power            ⌽
---     (U+00AE) registeredSign   ®
---     (U+23CE) return           ⏎
---     (U+21A9) return2          ↩
---     (U+2192) right            →
---     (U+21E2) right2           ⇢
---     (U+201D) rightDoubleQuote  ”
---     (U+2019) rightSingleQuote  ’
---     (U+00A7) sectionSign      §
---     (U+21E7) shift            ⇧
---     (U+2423) space            ␣
---     (U+21E5) tab              ⇥
---     (U+2191) up               ↑
---     (U+21E1) up2              ⇡
---
--- Notes:
---  * This variable is *NOT* part of the Lua 5.3.1 source code, and is provided for convenience within Hammerspoon.
---  * To see a list of the currently defined characters and labels, a __tostring meta-method is included so that referencing the table directly as a string will return the current definitions.
---    * For reference, this meta-method is essentially the following:
---
---      for i,v in hs.fnutils.sortByKeys(hs.utf8_53.registeredKeys) do print(string.format("(U+%04X) %-15s  %s", hs.utf8_53.codepoint(v), i, v)) end

module.registerCodepoint("alt",              0x2325)
module.registerCodepoint("apple",            0xF8FF)
module.registerCodepoint("backtab",          0x21E4)
module.registerCodepoint("capslock",         0x21EA)
module.registerCodepoint("cmd",              0x2318)
module.registerCodepoint("ctrl",             0x2303)
module.registerCodepoint("delete",           0x232B)
module.registerCodepoint("down",             0x2193)
module.registerCodepoint("down2",            0x21E3)
module.registerCodepoint("eject",            0x23CF)
module.registerCodepoint("end",              0x21F2)
module.registerCodepoint("end2",             0x2198)
module.registerCodepoint("escape",           0x238B)
module.registerCodepoint("forwarddelete",    0x2326)
module.registerCodepoint("help",             0xFE56)
module.registerCodepoint("home",             0x21F1)
module.registerCodepoint("home2",            0x2196)
module.registerCodepoint("home3",            0x21B8)
module.registerCodepoint("left",             0x2190)
module.registerCodepoint("left2",            0x21E0)
module.registerCodepoint("numlock",          0x21ED)
module.registerCodepoint("option",           0x2325)
module.registerCodepoint("padclear",         0x2327)
module.registerCodepoint("padenter",         0x2324)
module.registerCodepoint("padenter2",        0x2386)
module.registerCodepoint("padenter3",        0x21A9)
module.registerCodepoint("pagedown",         0x21DF)
module.registerCodepoint("pageup",           0x21DE)
module.registerCodepoint("power",            0x233D)
module.registerCodepoint("return",           0x23CE)
module.registerCodepoint("return2",          0x21A9)
module.registerCodepoint("right",            0x2192)
module.registerCodepoint("right2",           0x21E2)
module.registerCodepoint("shift",            0x21E7)
module.registerCodepoint("space",            0x2423)
module.registerCodepoint("tab",              0x21E5)
module.registerCodepoint("up",               0x2191)
module.registerCodepoint("up2",              0x21E1)
module.registerCodepoint("middleDot",        0x00B7)
module.registerCodepoint("leftSingleQuote",  0x2018)
module.registerCodepoint("rightSingleQuote", 0x2019)
module.registerCodepoint("leftDoubleQuote",  0x201C)
module.registerCodepoint("rightDoubleQuote", 0x201D)
module.registerCodepoint("sectionSign",      0x00A7)
module.registerCodepoint("copyrightSign",    0x00A9)
module.registerCodepoint("registeredSign",   0x00AE)
module.registerCodepoint("checkMark",        0x2713)

-- Return Module Object --------------------------------------------------

return module



