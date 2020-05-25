--- === hs.axuielement ===
---
--- This module allows you to access the accessibility objects of running applications, their windows, menus, and other user interface elements that support the OS X accessibility API.
---
--- This module works through the use of axuielementObjects, which is the Hammerspoon representation for an accessibility object.  An accessibility object represents any object or component of an OS X application which can be manipulated through the OS X Accessibility API -- it can be an application, a window, a button, selected text, etc.  As such, it can only support those features and objects within an application that the application developers make available through the Accessibility API.
---
--- The basic methods available to determine what attributes and actions are available for a given object are described in this reference documentation.  In addition, the module will dynamically add methods for the attributes and actions appropriate to the object, but these will differ between object roles and applications -- again we are limited by what the target application developers provide us.
---
--- The dynamically generated methods will follow one of the following templates:
---  * `object:<attribute>()`         - this will return the value for the specified attribute (see [hs.axuielement:attributeValue](#attributeValue) for the generic function this is based on).
---  * `object:set<attribute>(value)` - this will set the specified attribute to the given value (see [hs.axuielement:setAttributeValue](#setAttributeValue) for the generic function this is based on).
---  * `object:do<action>()`          - this request that the specified action is performed by the object (see [hs.axuielement:performAction](#performAction) for the generic function this is based on).
---
--- Where `<action>` and `<attribute>` can be the formal Accessibility version of the attribute or action name (a string usually prefixed with "AX") or without the "AX" prefix.  When the prefix is left off, the first letter of the action or attribute can be uppercase or lowercase.
---
--- The module also dynamically supports treating the axuielementObject useradata as an array, to access it's children (i.e. `#object` will return a number, indicating the number of direct children the object has, and `object[1]` is equivalent to `object:children()[1]` or, more formally, `object:attributeValue("AXChildren")[1]`).
---
--- You can also treat the axuielementObject userdata as a table of key-value pairs to generate a list of the dynamically generated functions: `for k, v in pairs(object) do print(k, v) end` (this is essentially what [hs.axuielement:dynamicMethods](#dynamicMethods) does).

local USERDATA_TAG = "hs.axuielement"

if not hs.accessibilityState(true) then
    hs.luaSkinLog.ef("%s - module requires accessibility to be enabled; fix in SystemPreferences -> Privacy & Security", USERDATA_TAG)
end

local module       = require(USERDATA_TAG..".internal")

-- local basePath = package.searchpath(USERDATA_TAG, package.path)
-- if basePath then
--     basePath = basePath:match("^(.+)/init.lua$")
--     if require"hs.fs".attributes(basePath .. "/docs.json") then
--         require"hs.doc".registerJSONFile(basePath .. "/docs.json")
--     end
-- end

local log  = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")
module.log = log

local fnutils = require("hs.fnutils")

require("hs.styledtext")

local objectMT = hs.getObjectMetatable(USERDATA_TAG)

local parentLabels = { module.attributes.general.parent, module.attributes.general.topLevelUIElement }

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.roles                   = ls.makeConstantsTable(module.roles)
module.subroles                = ls.makeConstantsTable(module.subroles)
module.parameterizedAttributes = ls.makeConstantsTable(module.parameterizedAttributes)
module.actions                 = ls.makeConstantsTable(module.actions)
module.attributes              = ls.makeConstantsTable(module.attributes)
module.directions              = ls.makeConstantsTable(module.directions)

module.observer.notifications  = ls.makeConstantsTable(module.observer.notifications)

--- hs.axuielement.systemElementAtPosition(x, y | pointTable) -> axuielementObject
--- Constructor
--- Returns the accessibility object at the specified position on the screen. The top-left corner of the primary screen is 0, 0.
---
--- Parameters:
---  * `x`, `y`     - the x and y coordinates of the screen location to test, provided as separate parameters
---  * `pointTable` - the x and y coordinates of the screen location to test, provided as a point-table, like the one returned by `hs.mouse.getAbsolutePosition`. A point-table is a table with key-value pairs for keys `x` and `y`.
---
--- Returns:
---  * an axuielementObject for the object at the specified coordinates, or nil if no object could be identified.
---
--- Notes:
---  * See also [hs.axuielement:elementAtPosition](#elementAtPosition) -- this function is a shortcut for `hs.axuielement.systemWideElement():elementAtPosition(...)`.
---
---  * This function does hit-testing based on window z-order (that is, layering). If one window is on top of another window, the returned accessibility object comes from whichever window is topmost at the specified location.
module.systemElementAtPosition = function(...)
    return module.systemWideElement():elementAtPosition(...)
end

-- build up the "correct" object metatable methods

objectMT.__index = function(self, _)
    if type(_) == "string" then
        -- take care of the internally defined items first so we can get out of here quickly if its one of them
        if objectMT[_] then return objectMT[_] end

        -- Now for the dynamically generated methods...

        local matchName = _:match("^set(.+)$")
        if not matchName then matchName = _:match("^do(.+)$") end
        if not matchName then matchName = _:match("^(.+)WithParameter$") end
        if not matchName then matchName = _ end
        local formalName = matchName:match("^AX[%w%d_]+$") and matchName or "AX"..matchName:sub(1,1):upper()..matchName:sub(2)

        -- luacheck: push ignore __

        -- check for setters
        if _:match("^set%u") then

             -- check attributes
             for __, v in ipairs(objectMT.attributeNames(self) or {}) do
                if v == formalName and objectMT.isAttributeSettable(self, formalName) then
                    return function(self2, ...) return objectMT.setAttributeValue(self2, formalName, ...) end
                end
            end

        -- check for doers
        elseif _:match("^do%u") then

            -- check actions
            for __, v in ipairs(objectMT.actionNames(self) or {}) do
                if v == formalName then
                    return function(self2, ...) return objectMT.performAction(self2, formalName, ...) end
                end
            end

        -- getter or bust
        else

            -- check attributes
            for __, v in ipairs(objectMT.attributeNames(self) or {}) do
                if v == formalName then
                    return function(self2, ...) return objectMT.attributeValue(self2, formalName, ...) end
                end
            end

            -- check paramaterizedAttributes
            for __, v in ipairs(objectMT.parameterizedAttributeNames(self) or {}) do
                if v == formalName then
                    return function(self2, ...) return objectMT.parameterizedAttributeValue(self2, formalName, ...) end
                end
            end
        end

        -- luacheck: pop

        -- guess it doesn't exist
        return nil
    elseif type(_) == "number" then
        local children = objectMT.attributeValue(self, "AXChildren")
        if children then
            return children[_]
        else
            return nil
        end
    else
        return nil
    end
end

objectMT.__call = function(_, cmd, ...)
    local fn = objectMT.__index(_, cmd)
    if fn and type(fn) == "function" then
        return fn(_, ...)
    elseif fn then
        return fn
    elseif cmd:match("^do%u") then
        error(tostring(cmd) .. " is not a recognized action", 2)
    elseif cmd:match("^set%u") then
        error(tostring(cmd) .. " is not a recognized attribute", 2)
    else
        return nil
    end
end

objectMT.__pairs = function(_)
    local keys = {}

    -- luacheck: push ignore __

    -- getters and setters for attributeNames
    for __, v in ipairs(objectMT.attributeNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        keys[partialName:sub(1,1):lower() .. partialName:sub(2)] = true
        if objectMT.isAttributeSettable(_, v) then
            keys["set" .. partialName] = true
        end
    end

    -- getters for paramaterizedAttributes
    for __, v in ipairs(objectMT.parameterizedAttributeNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        keys[partialName:sub(1,1):lower() .. partialName:sub(2) .. "WithParameter"] = true
    end

    -- doers for actionNames
    for __, v in ipairs(objectMT.actionNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        keys["do" .. partialName] = true
    end

    -- luacheck: pop

    return function(_, k)
            local v
            k, v = next(keys, k)
            if k then v = _[k] end
            return k, v
        end, _, nil
end

objectMT.__len = function(self)
    local children = objectMT.attributeValue(self, "AXChildren")
    if children then
        return #children
    else
        return 0
    end
end

--- hs.axuielement:dynamicMethods([keyValueTable]) -> table
--- Method
--- Returns a list of the dynamic methods (short cuts) created by this module for the object
---
--- Parameters:
---  * `keyValueTable` - an optional boolean, default false, indicating whether or not the result should be an array (false) or a table of key-value pairs (true).
---
--- Returns:
---  * If `keyValueTable` is true, this method returns a table of key-value pairs with each key being the name of a dynamically generated method, and the value being the corresponding function.  Otherwise, this method returns an array of the dynamically generated method names.
---
--- Notes:
---  * the dynamically generated methods are described more fully in the reference documentation header, but basically provide shortcuts for getting and setting attribute values as well as perform actions supported by the Accessibility object the axuielementObject represents.
objectMT.dynamicMethods = function(self, asKV)
    local results = {}
    for k, v in pairs(self) do
        if asKV then
            results[k] = v
        else
            table.insert(results, k)
        end
    end
    if not asKV then table.sort(results) end
    return ls.makeConstantsTable(results)
end

--- hs.axuielement:path() -> table
--- Method
--- Returns a table of axuielements tracing this object through its parent objects to the root for this element, most likely an application object or the system wide object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing this object and 0 or more parent objects representing the path from the root object to this element.
---
--- Notes:
---  * this object will always exist as the last element in the table (e.g. at `table[#table]`) with its most imemdiate parent at `#table - 1`, etc. until the rootmost object for this element is reached at index position 1.
---
---  * an axuielement object representing an application or the system wide object is its own rootmost object and will return a table containing only itself (i.e. `#table` will equal 1)
objectMT.path = function(self)
    local results, current = { self }, self
    while current:attributeValue("AXParent") do
        current = current("parent")
        table.insert(results, 1, current)
    end
    return results
end


local buildTreeHamster
buildTreeHamster = function(self, prams, depth, withParents, seen)
    if prams.cancel then return prams.msg end
    coroutine.applicationYield() -- luacheck: ignore

    if depth == 0 then return "** max depth exceeded" end
    seen  = seen or {}
    if getmetatable(self) == objectMT then
        local seenBefore = fnutils.find(seen, function(_) return _._element == self end)
        if seenBefore then return seenBefore end
        local thisObject = self:allAttributeValues() or {}
        thisObject._element = self
        thisObject._actions = self:actionNames()
        thisObject._attributes = self:attributeNames()
        thisObject._parameterizedAttributes = self:parameterizedAttributeNames()

        seen[self] = thisObject
        for k, v in pairs(thisObject) do
            if k ~= "_element" then
                if (type(v) == "table" and #v > 0) then
                    thisObject[k] = buildTreeHamster(v, prams, depth, withParents, seen)
                elseif getmetatable(v) == objectMT then
                    if not withParents and fnutils.contains(parentLabels, k) then
                    -- not diving into parents, but lets see if we've seen them already...
                        thisObject[k] = fnutils.find(seen, function(_) return _._element == v end) or v
                    else
                        thisObject[k] = buildTreeHamster(v, prams, depth - 1, withParents, seen)
                    end
                end
            end
        end
        return thisObject
    elseif type(self) == "table" then
        local results = {}
        for i,v in ipairs(self) do
            if (type(v) == "table" and #v > 0) or getmetatable(v) == objectMT then
                results[i] = buildTreeHamster(v, prams, depth - 1, withParents, seen)
            else
                results[i] = v
            end
        end
        return results
    end
    return self
end

--- hs.axuielement:buildTree(callback, [depth], [withParents]) -> buildTreeObject
--- Method
--- Captures all of the available information for the accessibility object and its children and returns it in a table for inspection.
---
--- Parameters:
---  * `callback` - a required function which should expect two arguments: a `msg` string specifying how the search ended, and a table contiaining the recorded information. `msg` will be "completed" when the search has completed normally (or reached the specified depth) and will contain a string starting with "**" if it terminates early for some reason (see Returns: section)
---  * `depth`    - an optional integer, default `math.huge`, specifying the maximum depth from the intial accessibility object that should be visited to identify child elements and their attributes.
---  * `withParents` - an optional boolean, default false, specifying whether or not an element's (or child's) attributes for `AXParent` and `AXTopLevelUIElement` should also be visited when identifying additional elements to include in the results table.
---
--- Returns:
---  * a `buildTreeObject` which contains metamethods allowing you to check to see if the build process has completed and cancel it early if desired:
---    * `buildTreeObject:isRunning()` - will return true if the traversal is still ongoing, or false if it has completed or been cancelled
---    * `buildTreeObject:cancel()`    - will cancel the currently running search and invoke the callback with the partial results already collected. The `msg` parameter for the calback will be "** cancelled".
---
--- Notes:
---  * this method utilizes coroutines to keep Hammerspoon responsive, but can be slow to complete if you do not specifiy a depth or if you start from an element that has a lot of children or has children with many elements (e.g. the application element for a web browser).
---
---  * The results of this method are not generally intended to be used in production programs; it is organized more for exploratory purposes when trying to understand how elements are related within a given application or to determine what elements might be worth targetting with more specific queries.
objectMT.buildTree = function(self, callback, depth, withParents)
    assert(
        type(callback) == "function" or (getmetatable(callback) or {}).__call,
        "buildTree requires a callback function; element:buildTree(callback, [depth], [withParents])"
    )
    if type(depth) == "boolean" and type(withParents) == "nil" then
        depth, withParents = nil, depth
    end
    depth = depth or math.huge

    local prams = {
        cancel = false,
        callback = callback, -- may add partial updates at some point
    }
    coroutine.wrap(function()
        local results = buildTreeHamster(self, prams, depth, withParents)
        callback(prams.msg or "completed", results)
    end)()

    return setmetatable({}, {
        __index = {
            cancel = function(_, msg)
                prams.cancel = true
                prams.msg = msg or "** cancelled"
            end,
            isRunning = function(_)
                return not prams.msg
            end,
        },
        __tostring = function(_)
            return USERDATA_TAG .. ":buildTree " .. tostring(self):match(USERDATA_TAG .. ": (.+)$")
        end,
--         __gc = function(_)
--             _:cancel("** gc on buildTree object")
--         end,
    })
end

-- Return Module Object --------------------------------------------------

return module
