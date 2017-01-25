
--- === hs._asm.axuielement ===
---
--- This module allows you to access the accessibility objects of running applications, their windows, menus, and other user interface elements that support the OS X accessibility API.
---
--- This is very much a work in progress, so bugs and comments are welcome.
---
--- This module works through the use of axuielementObjects, which is the Hammerspoon representation for an accessibility object.  An accessibility object represents any object or component of an OS X application which can be manipulated through the OS X Accessibility API -- it can be an application, a window, a button, selected text, etc.  As such, it can only support those features and objects within an application that the application developers make available through the Accessibility API.
---
--- The basic methods available to determine what attributes and actions are available for a given object are described in this reference documentation.  In addition, the module will dynamically add methods for the attributes and actions appropriate to the object, but these will differ between object roles and applications -- again we are limited by what the target application developers provide us.
---
--- The dynamically generated methods will follow one of the following templates:
---  * `object:*attribute*()`         - this will return the value for the specified attribute (see [hs._asm.axuielement:attributeValue](#attributeValue) for the generic function this is based on).
---  * `object:set*attribute*(value)` - this will set the specified attribute to the given value (see [hs._asm.axuielement:setAttributeValue](#setAttributeValue) for the generic function this is based on).
---  * `object:do*action*()`          - this request that the specified action is performed by the object (see [hs._asm.axuielement:performAction](#performAction) for the generic function this is based on).
---
--- Where *action* and *attribute* can be the formal Accessibility version of the attribute or action name (a string usually prefixed with "AX") or without the "AX" prefix.  When the prefix is left off, the first letter of the action or attribute can be uppercase or lowercase.
---
--- The module also dynamically supports treating the axuielementObject useradata as an array, to access it's children (i.e. `#object` will return a number, indicating the number of direct children the object has, and `object[1]` is equivalent to `object:children()[1]` or, more formally, `object:attributeValue("AXChildren")[1]`).
---
--- You can also treat the axuielementObject userdata as a table of key-value pairs to generate a list of the dynamically generated functions: `for k, v in pairs(object) do print(k, v) end` (this is essentially what [hs._asm.axuielement:dynamicMethods](#dynamicMethods) does).
---
---
--- Limited support for parameterized attributes is provided, but is not yet complete.  This is expected to see updates in the future.
---
--- An object observer is also expected to be added to receive notifications; however as this overlaps with `hs.uielement`, exactly how this will be done is still being considered.
---
--- Examples are (will be soon) provided in a separate document.

local USERDATA_TAG = "hs._asm.axuielement"
local module       = require(USERDATA_TAG..".internal")
local log          = require("hs.logger").new(USERDATA_TAG,"warning")
module.log         = log

local fnutils = require("hs.fnutils")
local inspect = require("hs.inspect")

require("hs.styledtext")

local objectMT = hs.getObjectMetatable(USERDATA_TAG)

local parentLabels = { module.attributes.general.parent, module.attributes.general.topLevelUIElement }

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
-- planning to experiment with using this with responses to functional queries... and I
-- don't want to keep loose generated data hanging around
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
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
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end

local elementSearchHamster
elementSearchHamster = function(element, searchParameters, isPattern, includeParents, seen)
    seen = seen or {}
    local results = {}

-- check an AXUIElement and its attributes

    if getmetatable(element) == objectMT then
        if fnutils.contains(seen, element) then return results end
        table.insert(seen, element)

    -- first check if this element itself belongs in the result set
        if objectMT.matches(element, searchParameters, isPattern) then
            table.insert(results, element)
        end

    -- now check any of it's attributes and if they are a userdata, check them
        for i, v in ipairs(objectMT.attributeNames(element) or {}) do
            if not fnutils.contains(parentLabels, v) or includeParents then
                local value = objectMT.attributeValue(element, v)
                if  type(value) == "table" or getmetatable(value) == objectMT then
                    local tempResults = elementSearchHamster(value, searchParameters, isPattern, includeParents, seen)
                    if #tempResults > 0 then
                        for i2, v2 in ipairs(tempResults) do -- flatten; we'll cull duplicates later
                            table.insert(results, v2)
                        end
                    end
                end
            end
        end

-- iterate over any table that has been passed in
    elseif type(element) == "table" then
        for i, v in ipairs(element) do
            if  type(v) == "table" or getmetatable(v) == objectMT then
                local tempResults = elementSearchHamster(v, searchParameters, isPattern, includeParents, seen)
                if #tempResults > 0 then
                    for i2, v2 in ipairs(tempResults) do -- flatten; we'll cull duplicates later
                        table.insert(results, v2)
                    end
                end
            end
        end

-- other types we just silently ignore; shouldn't happen anyways with the above checks before recursion
--    else
    end

    -- cull duplicates
    if #results > 0 then
        local holding, realResults = {}, {}
        for i,v in ipairs(results) do
            local found = false
            for k1, v1 in pairs(holding) do
                if v == v1 then found = true ; break end
            end
            if not found then
                holding[v] = true
                table.insert(realResults, v)
            end
        end
        results = realResults
    end

    return results
end

-- Public interface ------------------------------------------------------

module.roles                   = _makeConstantsTable(module.roles)
module.subroles                = _makeConstantsTable(module.subroles)
module.parameterizedAttributes = _makeConstantsTable(module.parameterizedAttributes)
module.actions                 = _makeConstantsTable(module.actions)
module.attributes              = _makeConstantsTable(module.attributes)
module.notifications           = _makeConstantsTable(module.notifications)
module.directions              = _makeConstantsTable(module.directions)

--- hs._asm.axuielement.systemElementAtPosition(x, y | { x, y }) -> axuielementObject
--- Constructor
--- Returns the accessibility object at the specified position in top-left relative screen coordinates.
---
--- Parameters:
---  * `x`, `y`   - the x and y coordinates of the screen location to test, provided as separate parameters
---  * `{ x, y }` - the x and y coordinates of the screen location to test, provided as a point-table, like the one returned by `hs.mouse.getAbsolutePosition`.
---
--- Returns:
---  * an axuielementObject for the object at the specified coordinates, or nil if no object could be identified.
---
--- Notes:
---  * See also [hs._asm.axuielement:elementAtPosition](#elementAtPosition) -- this function is a shortcut for `hs._asm.axuielement.systemWideElement():elementAtPosition(...)`.
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

        -- check for setters
        if _:match("^set") then

             -- check attributes
             for i, v in ipairs(objectMT.attributeNames(self) or {}) do
                if v == formalName and objectMT.isAttributeSettable(self, formalName) then
                    return function(self, ...) return objectMT.setAttributeValue(self, formalName, ...) end
                end
            end

        -- check for doers
        elseif _:match("^do") then

            -- check actions
            for i, v in ipairs(objectMT.actionNames(self) or {}) do
                if v == formalName then
                    return function(self, ...) return objectMT.performAction(self, formalName, ...) end
                end
            end

        -- getter or bust
        else

            -- check attributes
            for i, v in ipairs(objectMT.attributeNames(self) or {}) do
                if v == formalName then
                    return function(self, ...) return objectMT.attributeValue(self, formalName, ...) end
                end
            end

            -- check paramaterizedAttributes
            for i, v in ipairs(objectMT.parameterizedAttributeNames(self) or {}) do
                if v == formalName then
                    return function(self, ...) return objectMT.parameterizedAttributeValue(self, formalName, ...) end
                end
            end
        end

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
    else
        error(tostring(cmd) .. " is not a recognized attribute or action", 2)
    end
end

objectMT.__pairs = function(_)
    local keys = {}

     -- getters and setters for attributeNames
    for i, v in ipairs(objectMT.attributeNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        keys[partialName:sub(1,1):lower() .. partialName:sub(2)] = true
        if objectMT.isAttributeSettable(_, v) then
            keys["set" .. partialName] = true
        end
    end

    -- getters for paramaterizedAttributes
    for i, v in ipairs(objectMT.parameterizedAttributeNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        keys[partialName:sub(1,1):lower() .. partialName:sub(2) .. "WithParameter"] = true
    end

    -- doers for actionNames
    for i, v in ipairs(objectMT.actionNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        keys["do" .. partialName] = true
    end

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

--- hs._asm.axuielement:dynamicMethods([keyValueTable]) -> table
--- Method
--- Returns a list of the dynamic methods (short cuts) created by this module for the object
---
--- Parameters:
---  * `keyValueTable` - an optional boolean, default false, indicating whether or not the result should be an array or a table of key-value pairs.
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
    return _makeConstantsTable(results)
end

--- hs._asm.axuielement:matches(matchCriteria, [isPattern]) -> boolean
--- Method
--- Returns true if the axuielementObject matches the specified criteria or false if it does not.
---
--- Paramters:
---  * `matchCriteria` - the criteria to compare against the accessibility object
---  * `isPattern`     - an optional boolean, default false, specifying whether or not the strings in the search criteria should be considered as Lua patterns (true) or as absolute string matches (false).
---
--- Returns:
---  * true if the axuielementObject matches the criteria, false if it does not.
---
--- Notes:
---  * if `isPattern` is specified and is true, all string comparisons are done with `string.match`.  See the Lua manual, section 6.4.1 (`help.lua._man._6_4_1` in the Hammerspoon console).
---  * the `matchCriteria` must be one of the following:
---    * a single string, specifying the AXRole value the axuielementObject's AXRole attribute must equal for the match to return true
---    * an array of strings, specifying a list of AXRoles for which the match should return true
---    * a table of key-value pairs specifying a more complex match criteria.  This table will be evaluated as follows:
---      * each key-value pair is treated as a separate test and the object *must* match as true for all tests
---      * each key is a string specifying an attribute to evaluate.  This attribute may be specified with its formal name (e.g. "AXRole") or the informal version (e.g. "role" or "Role").
---      * each value may be a string, a number, a boolean, or an axuielementObject userdata object, or an array (table) of such.  If the value is an array, then the test will match as true if the object matches any of the supplied values for the attribute specified by the key.
---        * Put another way: key-value pairs are "and'ed" together while the values for a specific key-value pair are "or'ed" together.
---
---  * This method is used by [hs._asm.axuielement:elementSearch](#elementSearch) to determine if the given object should be included it's result set.  As an optimization for the `elementSearch` method, the keys in the `matchCriteria` table may be provided as a function which takes one argument (the axuielementObject to query).  The return value of this function will be compared against the value(s) of the key-value pair as described above.  This is done to prevent dynamically re-creating the query for each comparison when the search set is large.
objectMT.matches = function(self, searchParameters, isPattern)
    isPattern = isPattern or false
    if type(searchParameters) == "string" or #searchParameters > 0 then searchParameters = { role = searchParameters } end
    local answer = nil
    if getmetatable(self) == objectMT then
        answer = true
        for k, v in pairs(searchParameters) do
            local testFn = nil
            if type(k) == "string" then
                local formalName = k:match("^AX[%w%d_]+$") and k or "AX"..k:sub(1,1):upper()..k:sub(2)
                testFn = function(self) return objectMT.attributeValue(self, formalName) end
            elseif type(k) == "function" then
                testFn = k
            else
                local dbg = debug.getinfo(2)
                log.wf("%s:%d: type '%s' is not a valid key in searchParameters", dbg.short_src, dbg.currentline, type(k))
            end
            if testFn then
                local result = testFn(self)
                if type(v) ~= "table" then v = { v } end
                local partialAnswer = false
                for i2, v2 in ipairs(v) do
                    if type(v2) == type(result) then
                        if type(v2) == "string" then
                            partialAnswer = partialAnswer or (not isPattern and result == v2) or (isPattern and (type(result) == "string") and result:match(v2))
                        elseif type(v2) == "number" or type(v2) == "boolean" or getmetatable(v2) == objectMT then
                            partialAnswer = partialAnswer or (result == v2)
                        else
                            local dbg = debug.getinfo(2)
                            log.wf("%s:%d: unable to compare type '%s' in searchParameters", dbg.short_src, dbg.currentline, type(v2))
                        end
                    end
                    if partialAnswer then break end
                end
                answer = partialAnswer
            else
                answer = false
            end
            if not answer then break end
        end
    end
    return answer
end

--- hs._asm.axuielement:elementSearch(matchCriteria, [isPattern], [includeParents]) -> table
--- Method
--- Returns a table of axuielementObjects that match the specified criteria.  If this method is called for an axuielementObject, it will include all children of the element in its search.  If this method is called for a table of axuielementObjects, it will return the subset of the table that match the criteria.
---
--- Parameters:
---  * `matchCriteria`  - the criteria to compare against the accessibility objects
---  * `isPattern`      - an optional boolean, default false, specifying whether or not the strings in the search criteria should be considered as Lua patterns (true) or as absolute string matches (false).
---  * `includeParents` - an optional boolean, default false, indicating that the parent of objects should be queried as well.  If you wish to specify this parameter, you *must* also specify the `isPattern` parameter.  This parameter is ignored if the method is called on a result set from a previous invocation of this method or [hs._asm.axuielement:getAllChildElements](#getAllChildElements).
---
--- Returns:
---  * a table of axuielementObjects which match the specified criteria.  The table returned will include a metatable which allows calling this method on the result table for further narrowing the search.
---
--- Notes:
---  * this method makes heavy use of the [hs._asm.axuielement:matches](#matches) method and pre-creates the necessary dynamic functions to optimize its search.
---
---  * You can use this method to retrieve all of the current axuielementObjects for an application as follows:
--- ~~~
--- ax = require"hs._asm.axuielement"
--- elements = ax.applicationElement(hs.application("Safari")):elementSearch({})
--- ~~~
---  * Note that if you started from the window of an application, only the children of that window would be returned; you could force it to gather all of the objects for the application by using `:elementSearch({}, false, true)`.
---  * However, this method of querying for all elements can be slow -- it is highly recommended that you use [hs._asm.axuielement:getAllChildElements](#getAllChildElements) instead, and ideally with a callback function.
--- ~~~
--- ax = require"hs._asm.axuielement"
--- ax.applicationElement(hs.application("Safari")):getAllChildElements(function(t)
---     elements = t
---     print("done with query")
--- end)
--- ~~~
---  * Whatever option you choose, you can use this method to narrow down the result set. This example will print the frame for each button that was present in Safari when the search occurred which has a description which starts with "min" (e.g. "minimize button") or "full" (e.g. "full screen button"):
--- ~~~
--- for i, v in ipairs(elements:elementSearch({
---                                     role="AXButton",
---                                     roleDescription = { "^min", "^full"}
---                                 }, true)) do
---     print(hs.inspect(v:frame()))
--- end
--- ~~~
objectMT.elementSearch = function(self, searchParameters, isPattern, includeParents)
    isPattern = isPattern or false
    includeParents = includeParents or false
    if type(searchParameters) == "string" or #searchParameters > 0 then searchParameters = { role = searchParameters } end

    -- reduce overhead slightly by pre-creating the necessary attribute query functions
    -- rather than have __init do it for *every* comparison
    local spHolder = {}
    for k, v in pairs(searchParameters) do
        local formalName = k:match("^AX[%w%d_]+$") and k or "AX"..k:sub(1,1):upper()..k:sub(2)
        spHolder[function(self) return objectMT.attributeValue(self, formalName) end] = v
    end
    searchParameters = spHolder
    local results = {}
    if type(self) == "userdata" then
        results = elementSearchHamster(self, searchParameters, isPattern, includeParents)
    else
        for i,v in ipairs(self) do
            if objectMT.matches(v, searchParameters, isPattern) then
                table.insert(results, v)
            end
        end
    end

    return setmetatable(results, hs.getObjectMetatable(USERDATA_TAG .. ".elementSearchTable"))
end

objectMT.path = function(self)
    local results, current = { self }, self
    while current:attributeValue("AXParent") do
        current = current("parent")
        table.insert(results, 1, current)
    end
    return results
end

local buildTreeHamster
buildTreeHamster = function(self, depth, withParents, seen)
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
                    thisObject[k] = buildTreeHamster(v, depth, withParents, seen)
                elseif getmetatable(v) == objectMT then
                    if not withParents and fnutils.contains(parentLabels, k) then
                    -- not diving into parents, but lets see if we've seen them already...
                        thisObject[k] = fnutils.find(seen, function(_) return _._element == v end) or v
                    else
                        thisObject[k] = buildTreeHamster(v, depth - 1, withParents, seen)
                    end
                end
            end
        end
        return thisObject
    elseif type(self) == "table" then
        local results = {}
        for i,v in ipairs(self) do
            if (type(v) == "table" and #v > 0) or getmetatable(v) == objectMT then
                results[i] = buildTreeHamster(v, depth - 1, withParents, seen)
            else
                results[i] = v
            end
        end
        return results
    end
    return self
end

objectMT.buildTree = function(self, depth, withParents)
    if type(depth) == "boolean" and type(withParents) == "nil" then
        depth, withParents = nil, depth
    end
    depth = depth or math.huge
    return buildTreeHamster(self, depth, withParents)
end

objectMT.matchesCriteria = function(self, searchParameters, isPattern)
    isPattern = isPattern or false
    if type(searchParameters) == "string" or #searchParameters > 0 then searchParameters = { role = searchParameters } end
    local answer = nil
    if getmetatable(self) == objectMT then
        answer = true
        local values = self:allAttributeValues() or {}
        for k, v in pairs(searchParameters) do
            if not k:match("^_") then -- skip possible meta parameters
                local formalName = k:match("^AX[%w%d_]+$") and k or "AX"..k:sub(1,1):upper()..k:sub(2)
                local result = values[formalName]
                if type(v) ~= "table" then v = { v } end
                local partialAnswer = false
                for i2, v2 in ipairs(v) do
                    if type(v2) == type(result) then
                        if type(v2) == "string" then
                            partialAnswer = partialAnswer or (not isPattern and result == v2) or (isPattern and (type(result) == "string") and result:match(v2))
                        elseif type(v2) == "number" or type(v2) == "boolean" or getmetatable(v2) == objectMT then
                            partialAnswer = partialAnswer or (result == v2)
                        else
                            local dbg = debug.getinfo(2)
                            log.wf("%s:%d: unable to compare type '%s' in searchParameters", dbg.short_src, dbg.currentline, type(v2))
                        end
                    end
                    if partialAnswer then break end
                end
                answer = partialAnswer
                if not answer then break end
            end
        end
    end
    return answer
end

-- Identical criteria in a row will match on self for second criteria... need a way to avoid or detect...
--
-- maybe: add position parameter; include {self, 0} only if == 1;
-- include self's vars at 1 in searchable before loop if not already in there

local searchPathHamster = function(self, levelCriteria, levelDepth, withParents)
    local attached = debug.getuservalue(self) or {}
    local seen = attached.seen or {}
    local searchables = attached.searchables or {}
    if not attached.searchables then -- pre-populate a new list of potentials
        if levelCriteria._includeSelf then
            table.insert(searchables, { self, 0 })
        else
            local values = self:allAttributeValues() or {}
            for k,v in pairs(values) do
                if not fnutils.contains(parentLabels, k) or withParents then
                    if getmetatable(v) == objectMT then
                        table.insert(searchables, { v, 1 })
                    elseif type(v) == "table" and #v > 0 then
                        for i, v2 in ipairs(v) do
                            if getmetatable(v2) == objectMT then
                                table.insert(searchables, { v2, 1 })
                            end
                        end
                    end
                end
            end
        end
    end
    local found, haveWarnedAlready = false, false
    local count = levelCriteria._count or 1
    local addToParentIgnoreList = {}

    while #searchables > 0 and not found do
        local current = table.remove(searchables, 1)
        local element = current[1]
        if not fnutils.contains(seen, element) then
            table.insert(seen, element)
            if element:matchesCriteria(levelCriteria, levelCriteria._pattern) then
                count = count - 1
                table.insert(addToParentIgnoreList, element)
                if count == 0 then found = element end -- allow for "selecting the 2nd found", useful for arrays
            end
            -- go ahead and attach these even if found in case we're called again
            local newDepth = current[2] + 1
            if newDepth > levelDepth then
                if not haveWarnedAlready then
                    haveWarnedAlready = true
                    log.v("** max depth exceeded")
                end
            else
                local values = element:allAttributeValues() or {}
                for k,v in pairs(values) do
                    if not fnutils.contains(parentLabels, k) or withParents then
                        if getmetatable(v) == objectMT then
                            if not fnutils.contains(seen, v) then
                                table.insert(searchables, { v, newDepth })
                            end
                        elseif type(v) == "table" and #v > 0 then
                            for i, v2 in ipairs(v) do
                                if getmetatable(v2) == objectMT then
                                    if not fnutils.contains(seen, v2) then
                                        table.insert(searchables, { v2, newDepth })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- so I don't waste time changing this again -- we attached the currently seen and remaining searchables
    -- to the element which started the search, not the result of the search... :next will pop the last result
    -- for us since we shouldn't search deeper then the last criterion
    local uservalue = debug.getuservalue(self) or {}
    uservalue.seen        = seen
    uservalue.searchables = searchables
    debug.setuservalue(self, uservalue)
--     log.vf("seen: %d, searchable: %d", #seen, #searchables)
    return found, addToParentIgnoreList
end

local simpleCopy
simpleCopy = function(el, seen)
    seen = seen or {}
    local new
    if type(el) == "table" then
        new = seen[el]
        if not new then
            new = {}
            seen[el] = new
            for k, v in pairs(el) do
                new[k] = simpleCopy(v, seen)
            end
        end
    else
        new = el
    end
    return new
end

local searchPathWrapper = function(self, criteria, depth, withParents, path, criteriaSeen)
    local position = path and #criteria or 1
    path = path or { self:copy() }
    local failed = false

    if not criteriaSeen then
        criteriaSeen = {}
        criteria = simpleCopy(criteria) -- in case the table is being used outside of us, we want to capture it's state *now* for :next

        -- allow the first query item to match self if the user doesn't specify one way or the other
        if criteria[1] and type(criteria[1]._includeSelf) == "nil" then criteria[1]._includeSelf = true end

        for i, v in ipairs(criteria) do criteriaSeen[v] = {} end
    end

    while not failed and position <= #criteria do
        local element = path[#path]
        local levelCriteria = criteria[position]
        log.df("push:%s, searching for:%s", element:role(), inspect(levelCriteria):gsub("%s+", " "))
        local step, thingsToIgnore = searchPathHamster(element, levelCriteria, levelCriteria._depth or depth, withParents)
        if step then
            if not fnutils.contains(criteriaSeen[levelCriteria], step) then
                for i, v in ipairs(thingsToIgnore) do table.insert(criteriaSeen[levelCriteria], v) end
                table.insert(path, step)
                position = position + 1
            else
                step = nil
            end
        end
        if not step then
            log.df("pop: %s", element:role()) ;
            table.remove(path)
            position = position - 1
            if position == 0 then
                failed = true
            end
        end
    end

    local found = not failed and path[#path] or nil
    if found then
        local uservalue = debug.getuservalue(found) or {}
        uservalue.path         = path
        uservalue.criteria     = criteria
        uservalue.depth        = depth
        uservalue.withParents  = withParents
        uservalue.criteriaSeen = criteriaSeen
        debug.setuservalue(found, uservalue)
    end
    return found
end

objectMT.searchPath = function(self, criteria, depth, withParents)
    debug.setuservalue(self, nil) -- this is a brand new search, so clear anything that may remain
    criteria = criteria or {}
    if type(criteria) == "string" then criteria = { { role = criteria } } end
    if #criteria == 0 then criteria = { criteria } end
    if type(depth) == "boolean" and type(withParents) == "nil" then
        depth, withParents = nil, depth
    end
    depth = depth or math.huge
    return searchPathWrapper(self, criteria, depth, withParents)
end

objectMT.next = function(self)
    local uservalue = debug.getuservalue(self)
    if uservalue then
        table.remove(uservalue.path) -- we've already been found, so... pop us from the path
        return searchPathWrapper(self, uservalue.criteria, uservalue.depth, uservalue.withParents, uservalue.path, uservalue.criteriaSeen)
    else
        error("object does not possess search state information", 2)
    end
end

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()[USERDATA_TAG .. ".elementSearchTable"] = {
    __type  = USERDATA_TAG .. ".elementSearchTable",
    __index = { elementSearch = objectMT.elementSearch },
    __tostring = function(_)
        local results = ""
        for i, v in ipairs(_) do results = results..string.format("%d\t%s\n", i, tostring(v)) end
        return results
    end,
}

-- Return Module Object --------------------------------------------------

if module.types then module.types = _makeConstantsTable(module.types) end
return module
