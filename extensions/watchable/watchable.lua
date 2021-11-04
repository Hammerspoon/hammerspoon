--- === hs.watchable ===
---
--- A minimalistic Key-Value-Observer framework for Lua.
---
--- This module allows you to generate a table with a defined label or path that can be used to share data with other modules or code.  Other modules can register as watchers to a specific key-value pair within the watchable object table and will be automatically notified when the key-value pair changes.
---
--- The goal is to provide a mechanism for sharing state information between separate and (mostly) unrelated code easily and in an independent fashion.

local USERDATA_TAG = "hs.watchable"
-- local module       = require(USERDATA_TAG..".internal")
local module = {}

-- private variables and methods -----------------------------------------

local mt_object, mt_watcher
mt_object = {
    __watchers = {},
    __objects = setmetatable({}, {__mode = "kv"}),
    __values = setmetatable({}, {__mode = "k"}),
    __canChange = setmetatable({}, {__mode = "k"}),
    __name = USERDATA_TAG,
    __type = USERDATA_TAG,
    __index = function(self, index)
        return mt_object.__values[self][index]
    end,
    __newindex = function(self, index, value)
        local oldValue = mt_object.__values[self][index]
        mt_object.__values[self][index] = value
        if oldValue ~= value then
            local objectPath = mt_object.__objects[self]
            if mt_object.__watchers[objectPath] then
                if mt_object.__watchers[objectPath][index] then
                    for _, v in pairs(mt_object.__watchers[objectPath][index]) do
                        if v._active and v._callback then
                            v._callback(v, objectPath, index, oldValue, value)
                        end
                    end
                end
                if mt_object.__watchers[objectPath]["*"] then
                    for _, v in pairs(mt_object.__watchers[objectPath]["*"]) do
                        if v._active and v._callback then
                            v._callback(v, objectPath, index, oldValue, value)
                        end
                    end
                end
            end
        end
    end,
    __len = function(self)
        return #mt_object.__values[self]
    end,
    __pairs = function(self) return pairs(mt_object.__values[self]) end,
    __tostring = function(self) return USERDATA_TAG .. " table for path " .. mt_object.__objects[self] end,
}
-- mt_object.__metatable = mt_object.__index

mt_watcher = {
    __name = USERDATA_TAG .. ".watcher",
    __type = USERDATA_TAG .. ".watcher",
    __index = {
--- hs.watchable:pause() -> watchableObject
--- Method
--- Temporarily stop notifications about the key-value pair(s) watched by this watchableObject.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the watchableObject
        pause = function(self) self._active = false ; return self end,
--- hs.watchable:resume() -> watchableObject
--- Method
--- Resume notifications about the key-value pair(s) watched by this watchableObject which were previously paused.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the watchableObject
        resume = function(self) self._active = true ; return self end,
--- hs.watchable:release() -> nil
--- Method
--- Removes the watchableObject so that key-value pairs watched by this object no longer generate notifications.
---
--- Parameters:
---  * None
---
--- Returns:
---  * nil
        release = function(self)
            self._active = false
            if mt_object.__watchers[self._objPath][self._objKey] then -- may have already been removed by gc
                for _,v in pairs(mt_object.__watchers[self._objPath][self._objKey]) do
                    if v == self then mt_object.__watchers[self._objPath][self._objKey] = nil end
                end
            end
            setmetatable(self, nil)
            return nil
        end,
--- hs.watchable:callback(fn) -> watchableObject
--- Method
--- Change or remove the callback function for the watchableObject.
---
--- Parameters:
---  * `fn` - a function, or an explicit nil to remove, specifying the new callback function to receive notifications for this watchableObject
---
--- Returns:
---  * the watchableObject
---
--- Notes:
---  * see [hs.watchable.watch](#watch) for a description of the arguments the callback function should expect.
        callback = function(self, ...)
            local args = table.pack(...)
            local callback = args[1]
            if not callback and args.n == 0 then
                self._callback = nil
                return self
            elseif type(callback) == "function" then
                self._callback = callback
                return self
            else
                error("callback must be a function", 2)
            end
        end,
--- hs.watchable:value([key]) -> currentValue
--- Method
--- Get the current value for the key-value pair being watched by the watchableObject
---
--- Parameters:
---  * `key` - if the watchableObject was defined with a key of "*", this argument is required and specifies the specific key of the watched table to retrieve the value for.  If a specific key was specified when the watchableObject was defined, this argument is ignored.
---
--- Returns:
---  * The current value for the key-value pair being watched by the watchableObject. May be nil.
        value = function(self, key)
            local lookupKey = self._objKey
            if lookupKey == "*" and key == nil then
                error("key required for watched path with wildcard key", 2)
            elseif lookupKey == "*" then
                lookupKey = key
            end
            local object = mt_object.__objects[self._objPath]
            return object and object[lookupKey]
        end,
--- hs.watchable:change([key], value) -> watchableObject
--- Method
--- Externally change the value of the key-value pair being watched by the watchableObject
---
--- Parameters:
---  * `key`   - if the watchableObject was defined with a key of "*", this argument is required and specifies the specific key of the watched table to change the value of.  If a specific key was specified when the watchableObject was defined, this argument must not be provided.
---  * `value` - the new value for the key.
---
--- Returns:
---  * the watchableObject
---
--- Notes:
---  * if external changes are not allowed for the specified path, this method generates an error
        change = function(self, ...)
            local args = table.pack(...)
            local key, value
            if args.n == 1 then
                key, value = nil, args[1]
            elseif args.n == 2 then
                key, value = args[1], args[2]
            else
                error("value or key, value arguments expected", 2)
            end
            local lookupKey = self._objKey
            if lookupKey == "*" and key == nil then
                error("key required for watched path with wildcard key", 2)
            elseif lookupKey == "*" then
                lookupKey = key
            end
            local object = mt_object.__objects[self._objPath]
            if object and mt_object.__canChange[object] then
                object[lookupKey] = value
            else
                error("external changes disallowed for watched path " .. self._objPath, 2)
            end
        end,
    },
    __gc = function(self) self.release(self) end,
    __tostring = function(self) return USERDATA_TAG .. ".watcher for path " .. self._path end,
}
-- mt_watcher.__metatable = mt_watcher.__index

-- Public interface ------------------------------------------------------

--- hs.watchable.new(path, [externalChanges]) -> table
--- Constructor
--- Creates a table that can be watched by other modules for key changes
---
--- Parameters:
---  * `path`            - the global name for this internal table that external code can refer to the table as.
---  * `externalChanges` - an optional boolean, default false, specifying whether external code can make changes to keys within this table (bi-directional communication).
---
--- Returns:
---  * a table with metamethods which will notify external code which is registered to watch this table for key-value changes.
---
--- Notes:
---  * This constructor is used by code which wishes to share state information which other code may register to watch.
---
---  * You may specify any string name as a path, but it must be unique -- an error will occur if the path name has already been registered.
---  * All key-value pairs stored within this table are potentially watchable by external code -- if you wish to keep some data private, do not store it in this table.
---  * `externalChanges` will apply to *all* keys within this table -- if you wish to only allow some keys to be externally modifiable, you will need to register separate paths.
---  * If external changes are enabled, you will need to register your own watcher with [hs.watchable.watch](#watch) if action is required when external changes occur.
module.new = function(path, allowChange)
    allowChange = allowChange or false
    if type(path) ~= "string" then error ("path must be a string", 2) end
    if mt_object.__objects[path] then
        error(path .. " already registered", 2)
    end
    local self = setmetatable({}, mt_object)
    mt_object.__objects[path] = self
    mt_object.__objects[self] = path
    mt_object.__canChange[self] = allowChange
    mt_object.__values[self] = {}
    return self
end

--- hs.watchable.watch(path, [key], callback) -> watchableObject
--- Constructor
--- Creates a watcher that will be invoked when the specified key in the specified path is modified.
---
--- Parameters:
---  * `path`     - a string specifying the path to watch.  If `key` is not provided, then this should be a string of the form "path.key" where the key will be identified as the string after the last "."
---  * `key`      - if provided, a string specifying the specific key within the path to watch.
---  * `callback` - an optional function which will be invoked when changes occur to the key specified within the path.  The function should expect the following arguments:
---    * `watcher` - the watcher object itself
---    * `path`    - the path being watched
---    * `key`     - the specific key within the path which invoked this callback
---    * `old`     - the old value for this key, may be nil
---    * `new`     - the new value for this key, may be nil
---
--- Returns:
---  * a watchableObject
---
--- Notes:
---  * This constructor is used by code which wishes to watch state information which is being shared by other code.
---
---  * The callback function is invoked after the new value has already been set -- the callback is a "didChange" notification, not a "willChange" notification.
---
---  * If the key (specified as a separate argument or as the final component of path) is "*", then all key-value pair changes that occur for the table specified by the path will invoke a callback.  This is a shortcut for watching an entire table, rather than just a specific key-value pair of the table.
---  * It is possible to register a watcher for a path that has not been registered with [hs.watchable.new](#new) yet. Retrieving the current value with [hs.watchable:value](#value) in such a case will return nil.
module.watch = function(path, key, callback)
    if type(path) ~= "string" then error ("path must be a string", 2) end
    if type(key) == "function" or type(key) == "nil" then
        callback = key
        local objPath, objKey = path:match("^(.+)%.([^%.]+)$")
        if not (objPath and objKey) then error ("malformed path; must be of the form 'path.key' or path and key must be separate arguments", 2) end
        path = objPath
        key = objKey
    end
    if type(callback) ~= "function" and type(callback) ~= "nil" then error ("callback must be a function or nil", 2) end

    local objPath, objKey = path, key

    local self = setmetatable({
        _path = objPath .. "." .. objKey,
        _objKey = objKey,
        _objPath = objPath,
        _active = true,
        _callback = callback,
    }, mt_watcher)

    if not mt_object.__watchers[objPath] then mt_object.__watchers[objPath] = {} end
    if not mt_object.__watchers[objPath][objKey] then mt_object.__watchers[objPath][objKey] = setmetatable({}, {__mode = "v"}) end
    table.insert(mt_object.__watchers[objPath][objKey], self)

    return self
end

-- Return Module Object --------------------------------------------------

-- for debugging, may remove in the future
setmetatable(module, {
    __index = function(_, key)
        return ({
            mt_object  = mt_object,
            mt_watcher = mt_watcher,
        })[key] or nil -- the "or nil" isn't necessary but it makes our purpose clearer
    end,
})

return module
