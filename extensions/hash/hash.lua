--- === hs.hash ===
---
--- This module provides various hashing algorithms for use within Hammerspoon.
---
--- The currently supported hash types can be viewed by examining the [hs.hash.types](#types) constant.
---
--- In keeping with common hash library conventions to simplify the future addition of additional hash types, hash calculations in this module are handled in a three step manner, which is reflected in the constructor and methods defined for this module:
---
---  * First, the hash context is initialized. For this module, this occurs when you create a new hash object with [hs.hash.new(name, [secret])](#new).
---  * Second, data is "input" or appended to the hash with the [hs.hash:append(data)](#append) method. This may be invoked one or more times for the hash object before finalizing it, and order *is* important: `hashObject:append(data1):append(data2)` is different than `hashObject:append(data2):append(data1)`.
---  * Finally, you finalize or finish the hash with [hs.hash:finish()](#finish), which generates the final hash value. You can then retrieve the hash value with [hs.hash:value()](#value).
---
--- Most of the time, we only want to generate a hash value for a single data object; for this reason, meta-methods for this module allow you to use the following shortcut when computing a hash value:
---
---  * `hs.hash.<name>(data)` will return the hexadecimal version of the hash for the hash type `<name>` where `<name>` is one of the entries in [hs.hash.types](#types). This is syntacticly identical to `hs.hash.new(<name>):append(data):finish():value()`.
---  * `hs.hash.b<name>(data)` will return the binary version of the hash for the hash type '<name>'. This is syntacticly identical to `hs.hash.new(<name>):append(data):finish():value(true)`.
---  * In both cases above, if the hash name begins with `hmac`, the arguments should be `(secret, data)`, but otherwise act as described above. If additional shared key hash algorithms are added, this will be adjusted to continue to allow the shortcuts for the most common usage patterns.
---
--- The SHA3 code is based on code from the https://github.com/rhash/RHash project.
--- https://github.com/krzyzanowskim/CryptoSwift may also prove useful for future additions.

local USERDATA_TAG = "hs.hash"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
local fnutils      = require("hs.fnutils")
local fs           = require("hs.fs")

-- Public interface ------------------------------------------------------

--- hs.hash.SHA1(data) -> string
--- Deprecated
--- Calculates an SHA1 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data, encoded as hexadecimal
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("SHA1"):append(data):finish():value()`

--- hs.hash.SHA256(data) -> string
--- Deprecated
--- Calculates an SHA256 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data, encoded as hexadecimal
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("SHA256"):append(data):finish():value()`

--- hs.hash.SHA512(data) -> string
--- Deprecated
--- Calculates an SHA512 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data, encoded as hexadecimal
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("SHA512"):append(data):finish():value()`

--- hs.hash.MD5(data) -> string
--- Deprecated
--- Calculates an MD5 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data, encoded as hexadecimal
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("MD5"):append(data):finish():value()`

--- hs.hash.bSHA1(data) -> data
--- Deprecated
--- Calculates a binary SHA1 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the binary hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("SHA1"):append(data):finish():value(true)`

--- hs.hash.bSHA256(data) -> data
--- Deprecated
--- Calculates a binary SHA256 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the binary hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("SHA256"):append(data):finish():value(true)`

--- hs.hash.bSHA512(data) -> data
--- Deprecated
--- Calculates a binary SHA512 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the binary hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("SHA512"):append(data):finish():value(true)`

--- hs.hash.bMD5(data) -> data
--- Deprecated
--- Calculates a binary MD5 hash
---
--- Parameters:
---  * data - A string containing some data to hash
---
--- Returns:
---  * A string containing the binary hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("MD5"):append(data):finish():value(true)`

--- hs.hash.hmacSHA1(key, data) -> string
--- Deprecated
--- Calculates an HMAC using a key and a SHA1 hash
---
--- Parameters:
---  * key - A string containing a secret key to use
---  * data - A string containing the data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("hmacSHA1", key):append(data):finish():value()`

--- hs.hash.hmacSHA256(key, data) -> string
--- Deprecated
--- Calculates an HMAC using a key and a SHA256 hash
---
--- Parameters:
---  * key - A string containing a secret key to use
---  * data - A string containing the data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("hmacSHA256", key):append(data):finish():value()`

--- hs.hash.hmacSHA512(key, data) -> string
--- Deprecated
--- Calculates an HMAC using a key and a SHA512 hash
---
--- Parameters:
---  * key - A string containing a secret key to use
---  * data - A string containing the data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("hmacSHA512", key):append(data):finish():value()`

--- hs.hash.hmacMD5(key, data) -> string
--- Deprecated
--- Calculates an HMAC using a key and an MD5 hash
---
--- Parameters:
---  * key - A string containing a secret key to use
---  * data - A string containing the data to hash
---
--- Returns:
---  * A string containing the hash of the supplied data
---
--- Notes:
---  * this function is provided for backwards compatibility with a previous version of this module and is functionally equivalent to: `hs.hash.new("hmacMD5", key):append(data):finish():value()`

--- hs.hash.types
--- Constant
--- A tale containing the names of the hashing algorithms supported by this module.
---
--- At present, this module supports the following hash functions:
---
--- * CRC32      - Technically a checksum, not a hash, but often used for similar purposes, like verifying file integrity. Produces a 32bit value.
--- * MD5        - A message digest algorithm producing a 128bit hash value. MD5 is no longer consider secure for cryptographic purposes, but is still widely used to verify file integrity and other non cryptographic uses.
--- * SHA1       - A message digest algorithm producing a 160bit hash value. SHA-1 is no longer consider secure for cryptographic purposes, but is still widely used to verify file integrity and other non cryptographic uses.
--- * SHA256     - A cryptographic hash function that produces a 256bit hash value. While there has been some research into attack vectors on the SHA-2 family of algorithms, this is still considered sufficiently secure for many cryptographic purposes and for data validation and verification.
--- * SHA512     - A cryptographic hash function that produces a 512bit hash value. While there has been some research into attack vectors on the SHA-2 family of algorithms, this is still considered sufficiently secure for many cryptographic purposes and for data validation and verification.
--- * hmacMD5    - Combines the MD5 hash algorithm with a hash-based message authentication code, or pre-shared secret.
--- * hmacSHA1   - Combines the SHA1 hash algorithm with a hash-based message authentication code, or pre-shared secret.
--- * hmacSHA256 - Combines the SHA-2 256bit hash algorithm with a hash-based message authentication code, or pre-shared secret.
--- * hmacSHA512 - Combines the SHA-2 512bit hash algorithm with a hash-based message authentication code, or pre-shared secret.
--- * SHA3_224   - A SHA3 based cryptographic hash function that produces a 224bit hash value. The SHA3 family of algorithms use a different process than that which is used in the MD5, SHA1 and SHA2 families of algorithms and is considered the most cryptographically secure at present, though at the cost of additional computational complexity.
--- * SHA3_256   - A SHA3 based cryptographic hash function that produces a 256bit hash value. The SHA3 family of algorithms use a different process than that which is used in the MD5, SHA1 and SHA2 families of algorithms and is considered the most cryptographically secure at present, though at the cost of additional computational complexity.
--- * SHA3_384   - A SHA3 based cryptographic hash function that produces a 384bit hash value. The SHA3 family of algorithms use a different process than that which is used in the MD5, SHA1 and SHA2 families of algorithms and is considered the most cryptographically secure at present, though at the cost of additional computational complexity.
--- * SHA3_512   - A SHA3 based cryptographic hash function that produces a 512bit hash value. The SHA3 family of algorithms use a different process than that which is used in the MD5, SHA1 and SHA2 families of algorithms and is considered the most cryptographically secure at present, though at the cost of additional computational complexity.
table.sort(module.types)
module.types = ls.makeConstantsTable(module.types)

--- hs.hash.convertHexHashToBinary(input) -> string
--- Function
--- Converts a string containing a hash value as a string of hexadecimal digits into its binary equivalent.
---
--- Parameters:
---  * input - a string containing the hash value you wish to convert into its binary equivalent. The string must be a sequence of hexadecimal digits with an even number of characters.
---
--- Returns:
---  * a string containing the equivalent binary hash
---
--- Notes:
---  * this is a convenience function for use when you already have a hash value that you wish to convert to its binary equivalent. Beyond checking that the input string contains only hexadecimal digits and is an even length, the value is not actually validated as the actual hash value for anything specific.
module.convertHashToBinary = function(...)
    local args = table.pack(...)
    local input = args[1]
    assert(args.n == 1 and type(input) == "string" and #input % 2 == 0 and input:match("^%x+$"), "expected a string of hexidecimal digits")
    local output = ""
    for p in input:gmatch("%x%x") do output = output .. string.char(tonumber(p, 16)) end
    return output
end

--- hs.hash.convertBinaryHashToHex(input) -> string
--- Function
--- Converts a string containing a binary hash value to its equivalent hexadecimal digits.
---
--- Parameters:
---  * input - a string containing the binary hash value you wish to convert into its equivalent hexadecimal digits.
---
--- Returns:
---  * a string containing the equivalent hash as a string of hexadecimal digits
---
--- Notes:
---  * this is a convenience function for use when you already have a binary hash value that you wish to convert to its hexadecimal equivalent -- the value is not actually validated as the actual hash value for anything specific.
module.convertBinaryHashToHEX = function(...)
    local args = table.pack(...)
    local input = args[1]
    assert(args.n == 1 and type(input) == "string", "expected a string")
    local output = ""
    for p in input:gmatch(".") do output = output .. string.format("%02x", string.byte(p)) end
    return output
end

--- hs.hash.forFile(hash, [secret], path) -> string
--- Function
--- Calculates the specified hash value for the file at the given path.
---
--- Parameters:
---  * `hash`   - the name of the type of hash to calculate. This must be one of the string values found in the [hs.hash.types](#types) constant.
---  * `secret` - an optional string specifying the shared secret to prepare the hmac hash function with. For all other hash types this field is ignored. Leaving this parameter off when specifying an hmac hash function is equivalent to specifying an empty secret or a secret composed solely of null values.
---  * `path`   - the path to the file to calculate the hash value for.
---
--- Returns:
---  * a string containing the hexadecimal version of the calculated hash for the specified file.
---
--- Notes:
---  * this is a convenience function that performs the equivalent of `hs.new.hash(hash, [secret]):appendFile(path):finish():value()`.
module.forFile = function(...)
    local args = { ... }
    local hashFn = args[1]
    assert(type(hashFn) == "string" and fnutils.contains(module.types, hashFn), "hash type must be a string specifying one of the following -- " .. table.concat(module.types, ", "))

    local key  = hashFn:match("^hmac") and args[3] and args[2] or nil
    local path = hashFn:match("^hmac") and args[3] or args[2]

    local object = hashFn:match("^hmac") and module.new(hashFn, key) or module.new(hashFn)
    return object:appendFile(path):finish():value()
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(_, key)
        local realKey = key:match("^b(%w+)$") or key
        if fnutils.contains(module.types, realKey) then
            return function(...)
                local args   = { ... }
                local object
                if realKey:match("^hmac") then
                    local secret = table.remove(args, 1)
                    object = module.new(realKey, secret)
                else
                    object = module.new(realKey)
                end
                for _, v in ipairs(args) do object:append(v) end
                return object:finish():value(not not key:match("^b"))
            end
        end
    end,
    __call = function(_, key, ...)
        if fnutils.contains(module.types, key) then
            return _[key](...)
        else
            error(3, "attempt to call a table value")
        end
    end,
})
