--- === hs.utf8_53 ===
---
--- Functions providing basic support for UTF-8 encodings within Hammerspoon.  These functions are from the UTF-8 Library as provided by the [Lua 5.3.beta programming language](http://www.lua.org/work/). All I have provided is a wrapper to allow easy inclusion within the Hammerspoon environment.
---
--- The following text is from the preliminary [reference documentation](http://www.lua.org/work/doc/) for the Lua 5.3.beta programming language.
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

--- hs.utf8_53.codes(s) -> position, codepoint
--- Function
--- Returns values so that the construction
---     for p, c in utf8.codes(s) do body end
--- will iterate over all characters in string s, with p being the position (in bytes) and c the code point of each character. It raises an error if it meets any invalid byte sequence.

--- hs.utf8_53.codePoint(s [, i [, j]]) -> codepoint[, ...]
--- Function
--- Returns the codepoints (as integers) from all characters in s that start between byte position i and j (both included). The default for i is 1 and for j is i. It raises an error if it meets any invalid byte sequence.

--- hs.utf8_53.len(s [, i [, j]]) -> count | nil, position
--- Function
--- Returns the number of UTF-8 characters in string s that start between positions i and @{j} (both inclusive). The default for i is 1 and for j is -1. If it finds any invalid byte sequence, returns nil plus the position of the first invalid byte.

--- hs.utf8_53.offset(s, n [, i]) -> position
--- Function
--- Returns the position (in bytes) where the encoding of the n-th character of s (counting from position i) starts. A negative n gets characters before position i. The default for i is 1 when n is non-negative and #s + 1 otherwise, so that utf8.offset(s, -n) gets the offset of the n-th character from the end of the string. If the specified character is not in the subject or right after its end, the function returns nil.
--- As a special case, when n is 0 the function returns the start of the encoding of the character that contains the i-th byte of s.
---
--- This function assumes that s is a valid UTF-8 string.

--- hs.utf8_53.charPattern
--- Variable
---The pattern (a string, not a function) "[\0-\x7F\xC2-\xF4][\x80-\xBF]*" (see 6.4.1 in [reference documentation](http://www.lua.org/work/doc/)), which matches exactly one UTF-8 byte sequence, assuming that the subject is a valid UTF-8 string.

local module = require("hs.utf8_53.internal-utf8")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module



