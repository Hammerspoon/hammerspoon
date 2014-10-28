--- === hs.base64 ===
---
--- This module provides base64 encoding and decoding for Mjolnir.
---
--- Portions sourced from (https://gist.github.com/shpakovski/1902994).


local module = require("hs.base64.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.base64.encode(val[,width]) -> str
--- Function
--- Returns the base64 encoding of the string provided, optionally split into lines of `width` characters per line. Common widths seem to be 64 and 76 characters per line (except for the last line, which may be less), but as this is not standard or even required in all cases, we allow an arbitrary number to be chosen to fit your application's requirements.
module.encode = function(data, width)
    local _data = module._encode(data)
    if width then
        local _hold, i, j = _data, 1, width
        _data = ""
        repeat
            _data = _data.._hold:sub(i,j).."\n"
            i = i + width
            j = j + width
        until i > #_hold
    end
    return _data:sub(1,#_data - 1)
end

--- hs.base64.decode(str) -> val
--- Function
--- Returns a Lua string representing the given base64 string.
module.decode = function(data)
    return module._decode(data:gsub("[\r\n]+",""))
end

-- Return Module Object --------------------------------------------------

return module
