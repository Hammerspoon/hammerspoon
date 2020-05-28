--- === hs.axuielement ===
---
--- This module allows you to access the accessibility objects of running applications, their windows, menus, and other user interface elements that support the OS X accessibility API.
---
--- This module works through the use of axuielementObjects, which is the Hammerspoon representation for an accessibility object.  An accessibility object represents any object or component of an OS X application which can be manipulated through the OS X Accessibility API -- it can be an application, a window, a button, selected text, etc.  As such, it can only support those features and objects within an application that the application developers make available through the Accessibility API.
---
--- The basic methods available to determine what attributes and actions are available for a given object are described in this reference documentation.  In addition, the module will dynamically add methods for the attributes and actions appropriate to the object, but these will differ between object roles and applications -- again we are limited by what the target application developers provide us.
---
--- The dynamically generated methods will follow one of the following templates:
---  * `object:<attribute>()`            - this will return the value for the specified attribute (see [hs.axuielement:attributeValue](#attributeValue) for the generic function this is based on). If the element does not have this specific attribute, an error will be generated.
---  * `object("<attribute>")`           - this will return the value for the specified attribute. Returns nil if the element does not have this specific attribute instead of generating an error.
---  * `object:set<attribute>(value)`    - this will set the specified attribute to the given value (see [hs.axuielement:setAttributeValue](#setAttributeValue) for the generic function this is based on). If the element does not have this specific attribute or if it is not settable, an error will be generated.
---  * `object("set<attribute>", value)` - this will set the specified attribute to the given value. If the element does not have this specific attribute or if it is not settable, an error will be generated.
---  * `object:do<action>()`             - this request that the specified action is performed by the object (see [hs.axuielement:performAction](#performAction) for the generic function this is based on). If the element does not respond to this action, an error will be generated.
---  * `object("do<action>")`            - this request that the specified action is performed by the object. If the element does not respond to this action, an error will be generated.
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

-- local fnutils = require("hs.fnutils")

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
        if partialName then
            keys[partialName:sub(1,1):lower() .. partialName:sub(2)] = true
            if objectMT.isAttributeSettable(_, v) then
                keys["set" .. partialName] = true
            end
        end
    end

    -- getters for paramaterizedAttributes
    for __, v in ipairs(objectMT.parameterizedAttributeNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        if partialName then
            keys[partialName:sub(1,1):lower() .. partialName:sub(2) .. "WithParameter"] = true
        end
    end

    -- doers for actionNames
    for __, v in ipairs(objectMT.actionNames(_) or {}) do
        local partialName = v:match("^AX(.*)")
        if partialName then
            keys["do" .. partialName] = true
        end
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
---  * this object will always exist as the last element in the table (e.g. at `table[#table]`) with its most immediate parent at `#table - 1`, etc. until the rootmost object for this element is reached at index position 1.
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

--- hs.axuielement:matchesCriteria(criteria, [isPattern]) -> boolean
--- Method
--- Returns true if the axuielementObject matches the specified criteria or false if it does not.
---
--- Parameters:
---  * `criteria`  - the criteria to compare against the accessibility object
---  * `isPattern` - an optional boolean, default false, specifying whether or not the strings in the search criteria should be considered as Lua patterns (true) or as absolute string matches (false).
---
--- Returns:
---  * true if the axuielementObject matches the criteria, false if it does not.
---
--- Notes:
---  * if `isPattern` is specified and is true, all string comparisons are done with `string.match`.  See the Lua manual, section 6.4.1 (`help.lua._man._6_4_1` in the Hammerspoon console).
---  * the `criteria` parameter must be one of the following:
---    * a single string, specifying the AXRole value the axuielementObject's AXRole attribute must equal for the match to return true
---    * an array of strings, specifying a list of AXRoles for which the match should return true
---    * a table of key-value pairs specifying a more complex match criteria.  This table will be evaluated as follows:
---      * each key-value pair is treated as a separate test and the object *must* match as true for all tests
---      * each key is a string specifying an attribute to evaluate.  This attribute may be specified with its formal name (e.g. "AXRole") or the informal version (e.g. "role" or "Role").
---      * each value may be a string, a number, a boolean, or an axuielementObject userdata object, or an array (table) of such.  If the value is an array, then the test will match as true if the object matches any of the supplied values for the attribute specified by the key.
---        * Put another way: key-value pairs are "and'ed" together while the values for a specific key-value pair are "or'ed" together.
---
---  * This method is used by [hs.axuielement:elementSearch](#elementSearch) when a criteria is specified.
objectMT.matchesCriteria = function(self, criteria, isPattern)
    isPattern = isPattern or false
    if type(criteria) == "string" or #criteria > 0 then criteria = { role = criteria } end
    local answer = nil
    if getmetatable(self) == objectMT then
        answer = true
        local values = self:allAttributeValues() or {}
        for k, v in pairs(criteria) do
            local formalName = k:match("^AX[%w_]+$") and k or "AX"..k:sub(1,1):upper()..k:sub(2)
            local result = values[formalName]
            if type(v) ~= "table" then v = { v } end
            local partialAnswer = false
            for _, v2 in ipairs(v) do
                if type(v2) == type(result) then
                    if type(v2) == "string" then
                        partialAnswer = partialAnswer or (not isPattern and result == v2) or (isPattern and result:match(v2))
                    elseif type(v2) == "number" or type(v2) == "boolean" or getmetatable(v2) == objectMT then
                        partialAnswer = partialAnswer or (result == v2)
                    else
                        local dbg = debug.getinfo(2)
                        log.wf("%s:%d: unable to compare type '%s' in criteria", dbg.short_src, dbg.currentline, type(v2))
                    end
                end
                if partialAnswer then break end
            end
            answer = partialAnswer
            if not answer then break end
        end
    end
    return answer and true or false
end

--- hs.axuielement:buildTree(callback, [depth], [withParents]) -> elementSearchObject
--- Method
--- Captures all of the available information for the accessibility object and its children and returns it in a table for inspection.
---
--- Parameters:
---  * `callback` - a required function which should expect two arguments: a `msg` string specifying how the search ended, and a table containing the recorded information. `msg` will be "completed" when the search has completed normally (or reached the specified depth) and will contain a string starting with "**" if it terminates early for some reason (see Notes: section for more information)
---  * `depth`    - an optional integer, default `math.huge`, specifying the maximum depth from the initial accessibility object that should be visited to identify child elements and their attributes.
---  * `withParents` - an optional boolean, default false, specifying whether or not an element's (or child's) attributes for `AXParent` and `AXTopLevelUIElement` should also be visited when identifying additional elements to include in the results table.
---
--- Returns:
---  * an elementSearchObject as described in [hs.axuielement:elementSearch](#elementSearch)
---
--- Notes:
--- * The format of the `results` table passed to the callback for this method is primarily for debugging and exploratory purposes and may not be arranged for easy programatic evaluation.
---
---  * This method is syntactic sugar for `hs.axuielement:elementSearch(callback, { objectOnly = false, asTree = true, [maxDepth = depth], [includeParents = withParents] })`. Please refer to [hs.axuielement:elementSearch](#elementSearch) for details about the returned object and callback arguments.
objectMT.buildTree = function(self, callback, depth, withParents)
    return self:elementSearch(callback, nil, {
        objectOnly     = false,
        asTree         = true,
        maxDepth       = depth or math.huge,
        includeParents = withParents and true or false,
    })
end

--- hs.axuielement:allChildElements(callback, [withParents]) -> elementSearchObject
--- Method
--- Query the accessibility object for all child accessibility objects (and their children...).
---
--- Parameters:
---  * `callback`    - a required function which should expect two arguments: a `msg` string specifying how the search ended, and a table containing the discovered child elements. `msg` will be "completed" when the traversal has completed normally and will contain a string starting with "**" if it terminates early for some reason (see Notes: section for more information)
---  * `withParents` - an optional boolean, default false, indicating that the parent of objects (and their children) should be collected as well.
---
--- Returns:
---  * an elementSearchObject as described in [hs.axuielement:elementSearch](#elementSearch)
---
--- Notes:
---  * This method is syntactic sugar for `hs.axuielement:elementSearch(callback, { [includeParents = withParents] })`. Please refer to [hs.axuielement:elementSearch](#elementSearch) for details about the returned object and callback arguments.
objectMT.allChildElements = function(self, callback, withParents)
    return self:elementSearch(callback, nil, { includeParents = withParents and true or false })
end


-- used for metamethods on hs.axuielement:elementSearch results
local elementSearchResultsMT = {}
elementSearchResultsMT.__index = elementSearchResultsMT

local elementFilterHamster = function(self, state)
    local criteria    = state.criteria
    local isPattern   = state.isPattern
    local objectsOnly = state.objectsOnly
    local results = {}

    local criteriaEmpty = not(next(criteria) and true or false)

    for _,v in ipairs(self) do
        if state.cancel then break end
        if coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore

        state.visited = state.visited + 1
        local addThis = criteriaEmpty or (objectsOnly and v or v._element):matchesCriteria(criteria, isPattern)
        if addThis then
            state.matched = state.matched + 1
            table.insert(results, v)
        end
    end
    return setmetatable(results, elementSearchResultsMT)
end

elementSearchResultsMT.filter = function(self, criteria, isPattern, callback)
    if type(criteria) == "function" or (getmetatable(criteria) or {}).__call then
        criteria, isPattern, callback = {}, false, criteria
    end
    if type(isPattern) == "function" or (getmetatable(isPattern) or {}).__call then
        isPattern, callback = false, isPattern
    end
    criteria = criteria or {}
    isPattern = isPattern or false
    if callback then
        assert(
            type(callback) == "function" or (getmetatable(callback) or {}).__call, "expected function for filter callback"
        )
    end

    local state = {
        cancel      = false,
        callback    = callback, -- may add partial updates at some point
        criteria    = criteria,
        isPattern   = isPattern,
        objectsOnly = self[1] and (getmetatable(self[1]) == objectMT),
        matched     = 0,
        visited     = 0,
        started     = os.time(),
        finished    = nil,
    }

    if callback then
        local filterCoroutine
        filterCoroutine = coroutine.wrap(function()
            local results = elementFilterHamster(self, state)
            state.finished = os.time() - state.started
            callback(state.msg or "completed", results)
            filterCoroutine = nil -- ensure garbage collection doesn't happen until after we're done
        end)
        filterCoroutine()

        return setmetatable({}, {
            __index = {
                cancel = function(_, msg)
                    state.cancel = true
                    if msg then
                        state.msg = "** " .. tostring(msg)
                    else
                        state.msg = "** cancelled"
                    end
                end,
                isRunning = function(_)
                    return not state.msg
                end,
                matched = function(_)
                    return state.matched
                end,
                visited = function(_)
                    return state.visited
                end,
                runTime = function(_)
                    return state.finished or (os.time() - state.started)
                end,
            },
            __tostring = function(_)
                return USERDATA_TAG .. ":elementSearchObject " .. tostring(self):match(USERDATA_TAG .. ": (.+)$")
            end,
    -- For now, not requiring that they capture this value to prevent collection.
    --         __gc = function(_)
    --             _:cancel("gc on elementSearchObject object")
    --         end,
        })
    else
        return elementFilterHamster(self, state)
    end
end

-- used by hs.axuielement:elementSearch to do the heavy lifting. The search performed is a breadth first search.
local elementSearchHamsterBF = function(self, state)
    local queue   = { self }
    local depth   = 0
    -- allows use of userdata as key in hash table even though different userdata can refer to same object
    local seen    = setmetatable({ [self] = true }, {
                        __index = function(_self, key)
                            for k,v in pairs(_self) do
                                if k == key then return v end
                            end
                            return nil
                        end,
                        __newindex = function(_self, key, value)
                            for k,_ in pairs(_self) do
                                if k == key then
                                    rawset(_self, k, value)
                                    return
                                end
                            end
                            rawset(_self, key, value)
                        end
                    })
    local results = {}

    local criteria       = state.criteria
    local isPattern      = state.namedMods.isPattern
    local includeParents = state.namedMods.includeParents
    local maxDepth       = state.namedMods.maxDepth
    local objectOnly     = state.namedMods.objectOnly
    local asTree         = state.namedMods.asTree

    local criteriaEmpty = not(next(criteria) and true or false)

    while #queue > 0 do
        if state.cancel or maxDepth < depth then break end

        if coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore

        local element = table.remove(queue, 1)
        if getmetatable(element) == objectMT then
            state.visited = state.visited + 1
            if criteriaEmpty or element:matchesCriteria(criteria, isPattern) then
                state.matched = state.matched + 1
                local keeping = objectOnly and element or element:allAttributeValues() or {}
                if not objectOnly then
                    keeping._element                 = element
                    keeping._actions                 = element:actionNames()
                    keeping._attributes              = element:attributeNames()
                    keeping._parameterizedAttributes = element:parameterizedAttributeNames()
                    -- store the table of details so we can replace the axuielement objects in the final results for attributes and children with their details
                    seen[element] = keeping
                end
                table.insert(results, keeping)
            end
            if type(queue[#queue]) ~= "table" then table.insert(queue, {}) end
            local nxtLvlQueue = queue[#queue]
            local children = element("children") or {}
            for _,v in ipairs(children) do
                if not seen[v] then
                    seen[v] = true
                    table.insert(nxtLvlQueue, v)
                end
            end
            if includeParents then
                for _,v in ipairs(parentLabels) do
                    local pElement = element(v)
                    if pElement then
                        if not seen[v] then
                            seen[v] = true
                            table.insert(nxtLvlQueue, v)
                        end
                    end
                end
            end
        elseif type(element) == "table" then
            queue = element
            depth = depth + 1
        end
    end

    if not objectOnly then -- convert values that are axuielements to their table stored in `seen`
        local deTableValue
        deTableValue = function(val)
            if getmetatable(val) == objectMT then
                return seen[val] or val
            elseif type(val) == "table" then
                for k, v in pairs(val) do val[k] = deTableValue(v) end
            end
            return val
        end

        for _, element in ipairs(results) do
            for key, value in pairs(element) do
                if coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore

                if not key:match("^_") then -- skip our collections of actions, etc. and the element itself
                    element[key] = deTableValue(value)
                end
            end
        end
    end

    -- asTree is only valid (and in fact only works) if we captured all elements from the starting node and recorded their details
    if asTree and criteriaEmpty and not objectOnly then results = results[1] end

    if not asTree then
        return setmetatable(results, elementSearchResultsMT)
    else
        return results
    end
end

--- hs.axuielement:elementSearch(callback, [criteria], [namedModifiers]) -> elementSearchObject
--- Method
--- Search for and generate a table of the accessibility elements for the attributes and children of this object based on the specified criteria.
---
--- Parameters:
---  * `callback`       - a required function which will receive the results of this search. The callback should expect two arguments and return none. The arguments to the callback function will be `msg`, a string specifying how the search ended and `results`, a table containing the requested results. `msg` will be "completed" if the search completes normally, or a string starting with "**" if it is terminated early (see Returns: and Notes: for more details).
---  * `criteria`       - an optional table or string which will be passed to [hs.axuielement:matchesCriteria](#matchesCriteria) to determine if the discovered element should be included in the final result set. This criteria does not prune the search, it just determines if the element will be included in the results.
---  * `namedModifiers` - an optional table specifying key-value pairs that further modify or control the search. This table may contain 0 or more of the following keys:
---    * `isPattern`      - a boolean, default false, specifying whether or not all string values in `criteria` should be evaluated as patterns (true) or as literal strings to be matched (false). This value is passed to [hs.axuielement:matchesCriteria](#matchesCriteria) when `criteria` is specified and has no effect otherwise.
---    * `includeParents` - a boolean, default false, specifying whether or not parent attributes (`AXParent` and `AXTopLevelUIElement`) should be examined during the search. Note that in most cases, setting this value to true will end up traversing the entire Accessibility structure for the target application and may significantly slow down the search.
---    * `maxDepth`       - an optional integer, default `math.huge`, specifying the maximum number of steps from the initial accessibility element the search should visit. If you know that your desired element(s) are relatively close to your starting element, setting this to a lower value can significantly speed up the search.
---    * `objectOnly`     - an optional boolean, default true, specifying whether each result in the final table will be the accessibility element discovered (true) or a table containing details about the element include the attribute names, actions, etc. for the element (false). This latter format is primarily for debugging and exploratory purposes and may not be arranged for easy programatic evaluation.
---    * `asTree`         - an optional boolean, default false, and is ignored if `criteria` is specified and non-empty or `objectOnly` is true. This modifier specifies whether the search results should return as an array table of tables containing each element's details (false) or as a tree where in which the root node details are the key-value pairs of the returned table and child elements are likewise described in subtables attached to the attribute name they belong to (true). This format is primarily for debugging and exploratory purposes and may not be arranged for easy programatic evaluation.
---    * `noCallback`     - an optional boolean, default false, allowing you to specify nil as the callback when set to true. This feature requires setting this named argumennt to true and specifying the callback field as nil because starting a query from an element with a lot of descendants **WILL** block Hammerspoon and slow down the responsiveness of your computer (I've seen blocking for over 5 minutes in extreme cases) and should be used *only* when you know you are starting from close to the end of the element heirarchy. When this is true, this method returns just the results table. Ignored if `callback` is not also nil.
---
--- Returns:
---  * an elementSearchObject which contains metamethods allowing you to check to see if the process has completed and cancel it early if desired. The methods include:
---    * `elementSearchObject:cancel([reason])` - cancels the current search and invokes the callback with the partial results already collected. If you specify `reason`, the `msg` parameter for the callback will be `** <reason>`; otherwise it will be "** cancelled".
---    * `elementSearchObject:isRunning()`      - returns true if the search is still ongoing or false if it has completed or been cancelled
---    * `elementSearchObject:matched()`        - returns an integer specifying the number of elements which have already been found that meet the specified criteria.
---    * `elementSearchObject:visited()`        - returns an integer specifying the number of elements which have been examined during the search so far.
---    * `elementSearchObject:runTime()`        - returns an integer specifying the number of seconds since this search was started. Note that this is *not* an accurate measure of how much time has been spent *specifically* in the search because it will be greatly affected by how much other activity is occurring within Hammerspoon and on the users computer. Once the callback has been invoked, this will return the total time in seconds between when the search began and when it completed.
---
--- Notes:
---  * This method utilizes coroutines to keep Hammerspoon responsive, but may be slow to complete if `includeParents` is true, if you do not specify `maxDepth`, or if you start from an element that has a lot of children or has children with many elements (e.g. the application element for a web browser). This is dependent entirely upon how many active accessibility elements the target application defines and where you begin your search and cannot reliably be determined up front, so you may need to experiment to find the best balance for your specific requirements.
---
--- * The search performed is a breadth-first search, so in general earlier elements in the results table will be "closer" in the Accessibility hierarchy to the starting point than later elements.
---
--- * If `asTree` is false, the `results` table will be generated with metamethods allowing you to further filter the results by applying additional criteria. The following method is defined:
---   * `results:filter([criteria], [isPattern], [callback]) -> table`
---     * `criteria`  - an optional table or string which will be passed to [hs.axuielement:matchesCriteria](#matchesCriteria) to determine if the element should be included in the filtered result set.
---     * `isPattern` - an optional boolean, default false, specifying whether strings in the specified criteria should be treated as patterns (see [hs.axuielement:matchesCriteria](#matchesCriteria))
---     * `callback`  - an optional callback which should expect two arguments and return none. The arguments will be a message indicating how the filter terminated and the filtered results table. If this field is specified, the `filter` method will return a filterObject with the same metamethods as the `elementSearchObject` described above.
---
---   * By default, the filter method returns the filtered results table with the same metatable attached (fort further filtering). However, if your table is exceptionally large (for example if you used [hs.axuielement:allChildElements](#allChildElements) on an application like Safari), it may be better to use a callback here as well to keep Hammerspoon responsive.
---
--- * [hs.axuielement:allChildElements](#allChildElements) is syntactic sugar for `hs.axuielement:elementSearch(callback, { [includeParents = withParents] })`
--- * [hs.axuielement:buildTree](#buildTree) is syntactic sugar for `hs.axuielement:elementSearch(callback, { objectOnly = false, asTree = true, [maxDepth = depth], [includeParents = withParents] })`
objectMT.elementSearch = function(self, callback, criteria, namedModifiers)
    local namedModifierDefaults = {
        isPattern      = false,
        includeParents = false,
        maxDepth       = math.huge,
        objectOnly     = true,
        asTree         = false,
        noCallback     = false,
    }

    -- check to see if criteria left off and second arg is actually the namedModifiers table
    if type(namedModifiers) == "nil" and type(criteria) == "table" then
        local criteriaEmpty = false
        for k,_ in pairs(namedModifierDefaults) do
            if type(criteria[k]) ~= "nil" then
                criteriaEmpty = true
                break
            end
        end
        if criteriaEmpty then criteria, namedModifiers = nil, criteria end
    end
    -- set default values for criteria and namedModifiers if they aren't present
    criteria = criteria or {}
    if type(criteria) == "string" or #criteria > 0 then criteria = { role = criteria } end

    namedModifiers = namedModifiers or {}
    -- set defaults in namedModifiers for keys not provided
    for k,v in pairs(namedModifierDefaults) do
        if type(namedModifiers[k]) == "nil" then
            namedModifiers[k] = v
        end
    end

    if not (namedModifiers.noCallback and callback == nil) then
        assert(
            type(callback) == "function" or (getmetatable(callback) or {}).__call, "elementSearch requires a callback function"
        )
    end

    local state = {
        cancel    = false,
        callback  = callback, -- may add partial updates at some point
        criteria  = criteria,
        namedMods = namedModifiers,
        matched   = 0,
        visited   = 0,
        started   = os.time(),
        finished  = nil,
    }

    if callback then
        local searchCoroutine
        searchCoroutine = coroutine.wrap(function()
            local results = elementSearchHamsterBF(self, state)
            state.finished = os.time() - state.started
            callback(state.msg or "completed", results)
            searchCoroutine = nil -- ensure garbage collection doesn't happen until after we're done
        end)
        searchCoroutine()

        return setmetatable({}, {
            __index = {
                cancel = function(_, msg)
                    state.cancel = true
                    if msg then
                        state.msg = "** " .. tostring(msg)
                    else
                        state.msg = "** cancelled"
                    end
                end,
                isRunning = function(_)
                    return not state.msg
                end,
                matched = function(_)
                    return state.matched
                end,
                visited = function(_)
                    return state.visited
                end,
                runTime = function(_)
                    return state.finished or (os.time() - state.started)
                end,
            },
            __tostring = function(_)
                return USERDATA_TAG .. ":elementSearchObject " .. tostring(self):match(USERDATA_TAG .. ": (.+)$")
            end,
    -- For now, not requiring that they capture this value to prevent collection.
    --         __gc = function(_)
    --             _:cancel("gc on elementSearchObject object")
    --         end,
        })
    else
        return elementSearchHamsterBF(self, state)
    end
end

-- Return Module Object --------------------------------------------------

return module
