--- === hs.utf8 ===
---
--- Functions providing basic support for UTF-8 encodings
---
--- Prior to upgrading Hammerspoon's Lua interpreter to 5.3, UTF8 support was provided by including the then beta version of Lua 5.3's utf8 library as a Hammerspoon module.  This is no longer necessary, but to maintain compatibility, the Lua utf8 library can still be accessed through `hs.utf8`.  The documentation for the utf8 library can be found at http://www.lua.org/manual/5.3/ or from the Hammerspoon console via the help command: `help.lua.utf8`. This affects the following functions and variables:
---
---   * hs.utf8.char          - help available via `help.lua.utf8.char`
---   * hs.utf8.charPattern   - help available via `help.lua.utf8.charpattern`
---   * hs.utf8.codepoint     - help available via `help.lua.utf8.codepoint`
---   * hs.utf8.codes         - help available via `help.lua.utf8.codes`
---   * hs.utf8.len           - help available via `help.lua.utf8.len`
---   * hs.utf8.offset        - help available via `help.lua.utf8.offset`
---
--- Additional functions that are specific to Hammerspoon which provide expanded support for UTF8 are documented here.
---

-- Mirror utf8.X as hs.utf8.X in a case insensitive manner -- a little broader than
-- camelCase, but simpler then checking each individually for its "proper camel case"
-- version. -- edit: OK, so it's really only charPattern.. still, this is more portable
-- in case it's needed as a template for elsewhere.
local module = setmetatable({}, {
        __index = function(_, key)
            for i,v in pairs(package.loaded["utf8"]) do
                if string.lower(key) == i then return v end
            end
            return nil
        end
    })

local fnutils = require("hs.fnutils")

-- Public interface ------------------------------------------------------

-- see below -- we need it defined for the registration function, but documentation will be
-- given where we add the predefined keys.
module.registeredKeys = setmetatable({}, { __tostring = function(object)
            local output = ""
            for i,v in fnutils.sortByKeys(object) do
                output = output..string.format("(U+%04X) %-15s  %s\n", utf8.codepoint(v), i, v)
            end
            return output
    end,
    __call = function(_,x) return _[x] end,
})

--- hs.utf8.registeredLabels(utf8char) -> string
--- Function
--- Returns the label name for a UTF8 character, as it is registered in `hs.utf8.registeredKeys[]`.
---
--- Parameters:
---  * utf8char -- the character to lookup in `hs.utf8.registeredKeys[]`
---
--- Returns:
---  * The string label for the UTF8 character or a string in the format of "U+XXXX", if it is not defined in `hs.utf8.registeredKeys[]`, or nil, if utf8char is not a valid UTF8 character.
---
--- Notes:
---  * For parity with `hs.utf8.registeredKeys`, this can also be invoked as if it were an array: i.e. `hs.utf8.registeredLabels(char)` is equivalent to `hs.utf8.registeredLabels[char]`
local realRegisteredLabels = function(_, x)
    for i,v in pairs(module.registeredKeys) do
        if v == x then
            return i
        end
    end
    if x:match("^"..utf8.charpattern.."$") then
        return string.format("U+%04X",utf8.codepoint(x))
    else
        return nil
    end
end
module.registeredLabels = setmetatable({}, { __index = realRegisteredLabels, __call = realRegisteredLabels })

--- hs.utf8.codepointToUTF8(...) -> string
--- Function
--- Wrapper to `utf8.char(...)` which ensures that all codepoints return valid UTF8 characters.
---
--- Parameters:
---  * codepoints - A series of numeric Unicode code points to be converted to a UTF-8 byte sequences.  If a codepoint is a string (and does not start with U+, it is used as a key for lookup in `hs.utf8.registeredKeys[]`
---
--- Returns:
---  * A string containing the UTF-8 byte sequences corresponding to provided codepoints as a combined string.
---
--- Notes:
---  * Valid codepoint values are from 0x0000 - 0x10FFFF (0 - 1114111)
---  * If the codepoint provided is a string that starts with U+, then the 'U+' is converted to a '0x' so that lua can properly treat the value as numeric.
---  * Invalid codepoints are returned as the Unicode Replacement Character (U+FFFD)
---    * This includes out of range codepoints as well as the Unicode Surrogate codepoints (U+D800 - U+DFFF)
module.codepointToUTF8 = function(...)
    local listOfChars = table.pack(...)
    local result = ""

    for _,codepoint in ipairs(listOfChars) do
        if type(codepoint) == "string" then
            if codepoint:match("^U%+") then
                codepoint = codepoint:gsub("^U%+","0x")
            else
                codepoint = module.registeredKeys[codepoint] and utf8.codepoint(module.registeredKeys[codepoint]) or 0xFFFD
            end
        end
        codepoint = tonumber(codepoint)

        -- negatives not allowed
        if codepoint < 0 then result = result..utf8.char(0xFFFD)

        -- the surrogates cause print() to crash -- and they're invalid UTF-8 anyways
        elseif codepoint >= 0xD800 and codepoint <=0xDFFF then result = result..utf8.char(0xFFFD)

        -- single byte, 7-bit ascii
        elseif codepoint < 0x80 then result = result..string.char(codepoint)

        -- multibyte UTF8
        elseif codepoint <= 0x10FFFF then result = result..utf8.char(codepoint)

        -- greater than 0x10FFFF is invalid UTF-8
        else result = result..utf8.char(0xFFFD)
        end
    end

    return result
end

--- hs.utf8.fixUTF8(inString[, replacementChar]) -> outString, posTable
--- Function
--- Replace invalid UTF8 character sequences in `inString` with `replacementChar` so it can be safely displayed in the console or other destination which requires valid UTF8 encoding.
---
--- Parameters:
---  * inString - String of characters which may contain invalid UTF8 byte sequences
---  * replacementChar - optional parameter to replace invalid byte sequences in `inString`.  If this parameter is not provided, the default UTF8 replacement character, U+FFFD, is used.
---
--- Returns:
---  * outString - The contents of `inString` with all invalid UTF8 byte sequences replaced by the `replacementChar`.
---  * posTable - a table of indexes in `outString` corresponding indicating where `replacementChar` has been used.
---
--- Notes:
---  * This function is a slight modification to code found at http://notebook.kulchenko.com/programming/fixing-malformed-utf8-in-lua.
---  * If `replacementChar` is a multi-byte character (like U+FFFD) or multi character string, then the string length of `outString` will be longer than the string length of `inString`.  The character positions in `posTable` will reflect these new positions in `outString`.
---  * To calculate the character position of the invalid characters in `inString`, use something like the following:
---
---       outString, outErrors = hs.utf8.fixUTF8(inString, replacement)
---       inErrors = {}
---       for i,p in ipairs(outErrors) do
---           table.insert(inErrors, p - ((i - 1) * string.length(replacement) - 1))
---       end
---
---    Where replacement is `utf8.char(0xFFFD)`, if you leave it out of the `hs.utf8.fixUTF8` function in the first line.
---
module.fixUTF8 = function(s, replacement)
  replacement = replacement or utf8.char(0xFFFD)
  local p, len, invalid = 1, #s, {}
  local offset = string.len(replacement) - 1
  while p <= len do
    if     p == s:find("[%z\1-\127]", p) then p = p + 1
    elseif p == s:find("[\194-\223][\128-\191]", p) then p = p + 2
    elseif p == s:find(       "\224[\160-\191][\128-\191]", p)
        or p == s:find("[\225-\236][\128-\191][\128-\191]", p)
        or p == s:find(       "\237[\128-\159][\128-\191]", p)
        or p == s:find("[\238-\239][\128-\191][\128-\191]", p) then p = p + 3
    elseif p == s:find(       "\240[\144-\191][\128-\191][\128-\191]", p)
        or p == s:find("[\241-\243][\128-\191][\128-\191][\128-\191]", p)
        or p == s:find(       "\244[\128-\143][\128-\191][\128-\191]", p) then p = p + 4
    else
      s = s:sub(1, p-1)..replacement..s:sub(p+1)
      len = len + offset
      table.insert(invalid, p)
    end
  end
  return s, invalid
end

--- hs.utf8.registerCodepoint(label, codepoint) -> string
--- Function
--- Registers a Unicode codepoint under the given label as a UTF-8 string of bytes which can be referenced by the label later in your code as `hs.utf8.registeredKeys[label]` for convenience and readability.
---
--- Parameters:
---  * label - a string label to use as a human-readable reference when getting the UTF-8 byte sequence for use in other strings and output functions.
---  * codepoint - a Unicode codepoint in numeric or `U+xxxx` format to register with the given label.
---
--- Returns:
---  * Returns the UTF-8 byte sequence for the Unicode codepoint registered.
---
--- Notes:
---  * If a codepoint label was previously registered, this will overwrite the previous value with a new one.  Because many of the special keys you may want to register have different variants, this allows you to easily modify the existing predefined defaults to suite your preferences.
---  * The return value is merely syntactic sugar and you do not need to save it locally; it can be safely ignored -- future access to the pre-converted codepoint should be retrieved as `hs.utf8.registeredKeys[label]` in your code.  It looks good when invoked from the console, though ☺.
module.registerCodepoint = function(label, codepoint)
    module.registeredKeys[label] = module.codepointToUTF8(codepoint)
    return module.registeredKeys[label]
end

--- hs.utf8.registeredKeys[]
--- Variable
--- A collection of UTF-8 characters already converted from codepoint and available as convient key-value pairs.  UTF-8 printable versions of common Apple and OS X special keys are predefined and others can be added with `hs.utf8.registerCodepoint(label, codepoint)` for your own use.
---
--- Predefined keys include:
---
---     (U+2325) alt              ⌥
---     (U+F8FF) apple            
---     (U+21E4) backtab          ⇤
---     (U+21EA) capslock         ⇪
---     (U+2713) checkMark        ✓
---     (U+2318) cmd              ⌘
---     (U+27E1) concaveDiamond   ✧
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
---  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.utf8.registeredKeys`.
---  * For parity with `hs.utf8.registeredLabels`, this can also invoked as a function, i.e. `hs.utf8.registeredKeys["cmd"]` is equivalent to `hs.utf8.registeredKeys("cmd")`

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
module.registerCodepoint("concaveDiamond",   0x27E1)

--- hs.utf8.asciiOnly(string[, all]) -> string
--- Function
--- Returns the provided string with all non-printable ascii characters escaped, except Return, Linefeed, and Tab.
---
--- Parameters:
---  * string - The input string which is to have all non-printable ascii characters escaped as \x## (a single byte hexadecimal number).
---  * all    - an optional boolean parameter (default false) indicating whether or not Return, Linefeed, and Tab should also be considered "non-printable"
---
--- Returns:
---  * The cleaned up string, with non-printable characters escaped.
---
--- Notes:
---  * Because Unicode characters outside of the basic ascii alphabet are multi-byte characters, any UTF8 or other Unicode encoded character will be broken up into their individual bytes and likely escaped by this function.
---  * This function is useful for displaying binary data in a human readable way that might otherwise be inexpressible in the Hammerspoon console or other destination.  For example:
---    * `utf8.charpattern`, which contains the regular expression for matching valid UTF8 encoded sequences, results in `(null)` in the Hammerspoon console, but `hs.utf8.asciiOnly(utf8.charpattern)` will display `[\x00-\x7F\xC2-\xF4][\x80-\xBF]*`.
module.asciiOnly = function(theString, all)
    all = all or false
    if type(theString) == "string" then
        if all then
            return (theString:gsub("[\x00-\x1f\x7f-\xff]",function(a)
                    return string.format("\\x%02X",string.byte(a))
                end))
        else
            return (theString:gsub("[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\xff]",function(a)
                    return string.format("\\x%02X",string.byte(a))
                end))
        end
    else
        error("string expected", 2) ;
    end
end

--- hs.utf8.hexDump(inputString [, count]) -> string
--- Function
--- Returns a hex dump of the provided string.  This is primarily useful for examining the exact makeup of binary data contained in a Lua String as individual bytes for debugging purposes.
---
--- Parameters:
---  * inputString - the data to be rendered as individual hexadecimal bytes for examination.
---  * count - an optional parameter specifying the number of bytes to display per line (default 16)
---
--- Returns:
---  * a string containing the hex dump of the input string.
---
--- Notes:
---  * Like hs.utf8.asciiOnly, this function will break up Unicode characters into their individual bytes.
---  * As an example:
---      `hs.utf8.hexDump(utf8.charpattern)` will return
---      `00 : 5B 00 2D 7F C2 2D F4 5D 5B 80 2D BF 5D 2A        : [.-..-.][.-.]*`
module.hexDump = function(stuff, linemax)
    local ascii = ""
    local count = 0
    linemax = tonumber(linemax) or 16
    local buffer = ""
    local rb = ""
    local offset = math.floor(math.log(#stuff,16)) + 1
    offset = offset + (offset % 2)

    local formatstr = "%0"..tostring(offset).."x : %-"..tostring(linemax * 3).."s : %s"

    for c in string.gmatch(tostring(stuff), ".") do
        buffer = buffer..string.format("%02X ",string.byte(c))
        -- using string.gsub(c,"%c",".") didn't work in Hydra, but I didn't dig any deeper -- this works.
        if string.byte(c) < 32 or string.byte(c) > 126 then
            ascii = ascii.."."
        else
            ascii = ascii..c
        end
        count = count + 1
        if count % linemax == 0 then
            rb = rb .. string.format(formatstr, count - linemax, buffer, ascii) .. "\n"
            buffer=""
            ascii=""
        end
    end
    if count % linemax ~= 0 then
        rb = rb .. string.format(formatstr, count - (count % linemax), buffer, ascii) .. "\n"
    end
    return rb
end


-- Return Module Object --------------------------------------------------

return module
