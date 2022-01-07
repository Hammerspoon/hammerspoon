--- === hs.base64 ===
---
--- Base64 encoding and decoding
---
--- Portions sourced from (https://gist.github.com/shpakovski/1902994).


local module = require("hs.libbase64")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.base64.encode(val[,width]) -> str
--- Function
--- Encodes a given string to base64
---
--- Parameters:
---  * val - A string to encode as base64
---  * width - Optional line width to split the string into (usually 64 or 76)
---
--- Returns:
---  * A string containing the base64 representation of the input string
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
        return _data:sub(1,#_data - 1)
    else
        return _data
    end
end

--- hs.base64.decode(str) -> val
--- Function
--- Decodes a given base64 string
---
--- Parameters:
---  * str - A base64 encoded string
---
--- Returns:
---  * A string containing the decoded data
module.decode = function(data)
    return module._decode((data:gsub("[\r\n]+","")))
end

-- Return Module Object --------------------------------------------------

return module
