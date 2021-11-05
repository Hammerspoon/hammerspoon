--- === hs.axuielement ===
---
--- This module allows you to access the accessibility objects of running applications, their windows, menus, and other user interface elements that support the OS X accessibility API.
---
--- This module works through the use of axuielementObjects, which is the Hammerspoon representation for an accessibility object.  An accessibility object represents any object or component of an OS X application which can be manipulated through the OS X Accessibility API -- it can be an application, a window, a button, selected text, etc.  As such, it can only support those features and objects within an application that the application developers make available through the Accessibility API.
---
--- In addition to the formal methods described in this documentation, dynamic methods exist for accessing element attributes and actions. These will differ somewhat between objects as the specific attributes and actions will depend upon the accessibility object's role and purpose, but the following outlines the basics.
---
--- Getting and Setting Attribute values:
---  * `object.attribute` is a shortcut for `object:attributeValue(attribute)`
---  * `object.attribute = value` is a shortcut for `object:setAttributeValue(attribute, value)`
---    * If detecting accessiblity errors that may occur is necessary, you must use the formal methods [hs.axuielement:attributeValue](#attributeValue) and [hs.axuielement:setAttributeValue](#setAttributeValue)
---    * Note that setting an attribute value is not guaranteeed to work with either method:
---      * internal logic within the receiving application may decline to accept the newly assigned value
---      * an accessibility error may occur
---      * the element may not be settable (surprisingly this does not return an error, even when [hs.axuielement:isAttributeSettable](#isAttributeSettable) returns false for the attribute specified)
---    * If you require confirmation of the change, you will need to check the value of the attribute with one of the methods described above after setting it.
---
--- Iteration over Attributes:
---  * `for k,v in pairs(object) do ... end` is a shortcut for `for k,_ in ipairs(object:attributeNames()) do local v = object:attributeValue(k) ; ... end` or `for k,v in pairs(object:allAttributeValues()) do ... end` (though see note below)
---     * If detecting accessiblity errors that may occur is necessary, you must use one of the formal approaches [hs.axuielement:allAttributeValues](#allAttributeValues) or [hs.axuielement:attributeNames](#attributeNames) and [hs.axuielement:attributeValue](#attributeValue)
---    * By default, [hs.axuielement:allAttributeValues](#allAttributeValues) will not include key-value pairs for which the attribute (key) exists for the element but has no assigned value (nil) at the present time. This is because the value of `nil` prevents the key from being retained in the table returned. See [hs.axuielement:allAttributeValues](#allAttributeValues) for details and a workaround.
---
--- Iteration over Child Elements (AXChildren):
---  * `for i,v in ipairs(object) do ... end` is a shortcut for `for i,v in pairs(object:attributeValue("AXChildren") or {}) do ... end`
---    * Note that `object:attributeValue("AXChildren")` *may* return nil if the object does not have the `AXChildren` attribute; the shortcut does not have this limitation.
---  * `#object` is a shortcut for `#object:attributeValue("AXChildren")`
---  * `object[i]` is a shortcut for `object:attributeValue("AXChildren")[i]`
---    * If detecting accessiblity errors that may occur is necessary, you must use the formal method [hs.axuielement:attributeValue](#attributeValue) to get the "AXChildren" attribute.
---
--- Actions ([hs.axuielement:actionNames](#actionNames)):
---  * `object:do<action>()` is a shortcut for `object:performAction(action)`
---    * See [hs.axuielement:performAction](#performAction) for a description of the return values and [hs.axuielement:actionNames](#actionNames) to get a list of actions that the element supports.
---
--- ParameterizedAttributes:
---  * `object:<attribute>WithParameter(value)` is a shortcut for `object:parameterizedAttributeValue(attribute, value)
---    * See [hs.axuielement:parameterizedAttributeValue](#parameterizedAttributeValue) for a description of the return values and [hs.axuielement:parameterizedAttributeNames](#parameterizedAttributeNames) to get a list of parameterized values that the element supports
---
---    * The specific value required for a each parameterized attribute is different and is often application specific thus requiring some experimentation. Notes regarding identified parameter types and thoughts on some still being investigated will be provided in the Hammerspoon Wiki, hopefully shortly after this module becomes part of a Hammerspoon release.
local USERDATA_TAG = "hs.axuielement"

if not hs.accessibilityState(true) then
    hs.luaSkinLog.ef("%s - module requires accessibility to be enabled; fix in SystemPreferences -> Privacy & Security", USERDATA_TAG)
end

local module       = require("hs.libaxuielement")

require"hs.doc".registerJSONFile(hs.processInfo["resourcePath"].."/docs.json")
local basePath = package.searchpath(USERDATA_TAG, package.path)

local log  = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")
module.log = log

local fnutils     = require("hs.fnutils")
local application = require("hs.application")
local window      = require("hs.window")

-- included for their lua<->NSObject helpers
require("hs.styledtext")
require("hs.drawing.color")
require("hs.image")
require("hs.sharing")

local objectMT = hs.getObjectMetatable(USERDATA_TAG)

local parentLabels = { module.attributes.parent, module.attributes.topLevelUIElement }

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.parameterizedAttributes = ls.makeConstantsTable(module.parameterizedAttributes)
module.actions                 = ls.makeConstantsTable(module.actions)
module.attributes              = ls.makeConstantsTable(module.attributes)

module.roles                   = ls.makeConstantsTable(module.roles)
module.subroles                = ls.makeConstantsTable(module.subroles)
module.sortDirections          = ls.makeConstantsTable(module.sortDirections)
module.orientations            = ls.makeConstantsTable(module.orientations)
module.rulerMarkers            = ls.makeConstantsTable(module.rulerMarkers)
module.units                   = ls.makeConstantsTable(module.units)

module.observer.notifications  = ls.makeConstantsTable(module.observer.notifications)

--- hs.axuielement.systemElementAtPosition(x, y | pointTable) -> axuielementObject
--- Constructor
--- Returns the accessibility object at the specified position on the screen. The top-left corner of the primary screen is 0, 0.
---
--- Parameters:
---  * `x` - the x coordinate of the screen location to test
---  * `y` - the y coordinate of the screen location to test
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

objectMT.__index = function(self, key)
    if type(key) == "string" then
        -- take care of the internally defined items first so we can get out of here quickly if its one of them
        if objectMT[key] then return objectMT[key] end

        -- Now for the dynamically generated stuff...

        local doer, parameterized = false, false

        local AXName = key:match("^do(%u[%w_]*)$")
        if AXName then
            doer = true
        else
            AXName = key:match("^([%w_]+)WithParameter$")
            if AXName then
                parameterized = true
            else
                AXName = key
            end
        end

        if doer then
            for _, v in ipairs(objectMT.actionNames(self) or {}) do
                if v == AXName then
                    return function(self2, ...) return objectMT.performAction(self2, v, ...) end
                end
            end
        elseif parameterized then
            for _, v in ipairs(objectMT.parameterizedAttributeNames(self) or {}) do
                if v == AXName then
                    return function(self2, ...) return objectMT.parameterizedAttributeValue(self2, v, ...) end
                end
            end
        else
            for _, v in ipairs(objectMT.attributeNames(self) or {}) do
                if v == AXName then
                    return objectMT.attributeValue(self, v)
                end
            end
        end

        -- guess it doesn't exist
        return nil
    elseif type(key) == "number" then
        local children = objectMT.attributeValue(self, "AXChildren") or {}
        return children[key]
    else
        return nil
    end
end

objectMT.__newindex = function(self, key, value)
    for _, v in ipairs(objectMT.attributeNames(self) or {}) do
        if v == key then
            local ok, err = self:setAttributeValue(v, value) -- luacheck: ignore
-- undecided if this should generate an error when an accessibility error occurs. it's more "table" like if it
-- doesn't; otoh table assignment never fail unless you try with a key of `nil` and then it *does* throw an
-- error... the docs above do say that you should use setAttributeValue if you care about accssibility errors,
-- so unless/until someone complains I guess I'll leave the next line commented out
--             if not ok then error(err, 2) end
            return
        end
    end
-- in this case it's not an attribute they're trying to set, so an error does make sense
    error("attempt to index a " .. USERDATA_TAG .. " value", 2)
end

-- too many optional ways to access things was becoming confusing even for me, so commenting this out
-- it would allow you to use object("AXSomething") for properties, object("doAXSomething") for actions
-- and object("AXSomethingWithParameter", value) for parameterized attributes.
--
-- objectMT.__call = function(self, cmd, ...)
--     local fn = objectMT.__index(self, cmd)
--     if fn and type(fn) == "function" then
--         return fn(self, ...)
--     elseif fn then
--         return fn
--     elseif cmd:match("^do%u") then
--         error(tostring(cmd) .. " is not a recognized action", 2)
--     else
--         return nil
--     end
-- end

objectMT.__pairs = function(self)
    local keys = {}
    -- rather than capture all attribute values at outset, we just capture key names so
    -- the generator function can get the latest values in case something changes during
    -- iteration
    for _,v in ipairs(objectMT.attributeNames(self)) do keys[v] = true end

     return function(_, k)
            local v
            k, v = next(keys, k)
            if k then v = self:attributeValue(k) end
            return k, v
        end, self, nil
end

objectMT.__len = function(self)
    local children = objectMT.attributeValue(self, "AXChildren") or {}
    return #children
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
        current = current.AXParent
        table.insert(results, 1, current)
    end
    return results
end

local tableCopyNoMT
tableCopyNoMT = function(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    local copy = {}
    seen[t] = copy
    for k,v in pairs(t) do
        copy[k] = (type(v) == "table") and (seen[v] or tableCopyNoMT(v, seen)) or v
    end
    return copy
end

--- hs.axuielement:matchesCriteria(criteria) -> boolean
--- Method
--- Returns true if the axuielementObject matches the specified criteria or false if it does not.
---
--- Parameters:
---  * `criteria`  - the criteria to compare against the accessibility object
---
--- Returns:
---  * true if the axuielementObject matches the criteria, false if it does not.
---
--- Notes:
---  * the `criteria` argument must be one of the following:
---    * a single string, specifying the value the element's AXRole attribute must equal for a positive match
---
---    * an array table of strings specifying a list of possible values the element's AXRole attribute can equal for a positive match
---
---    * a table of key-value pairs specifying a more complex criteria. The table should be defined as follows:
---      * one or more of the following must be specified (though all specified must match):
---        * `attribute`              -- a string, or table of strings, specifying attributes that the element must support.
---        * `action`                 -- a string, or table of strings, specifying actions that the element must be able to perform.
---        * `parameterizedAttribute` -- a string, or table of strings, specifying parametrized attributes that the element must support.
---
---      * if the `attribute` key is specified, you can use one of the the following to specify a specific value the attribute must equal for a positive match. No more than one of these should be provided. If neither are present, then only the existence of the attributes specified by `attribute` are required.
---        * `value`                  -- a value, or table of values, that a specifeid attribute must equal. If it's a table, then only one of the values has to match the attribute value for a positive match. Note that if you specify more than one attribute with the `attribute` key, you must provide at least one value for each attribute in this table (order does not matter, but the match will fail if any atrribute does not match at least one value provided).
---        * `nilValue`               -- a boolean, specifying that the attributes must not have an assigned value (true) or may be assigned any value except nil (false). If the `value` key is specified, this key is ignored. Note that this applies to *all* of the attributes specified with the `attribute` key.
---
---      * the following are optional keys and are not required:
---        * `pattern`                -- a boolean, default false, specifying whether string matches for attribute values should be evaluated with `string.match` (true) or as exact matches (false). See the Lua manual, section 6.4.1 (`help.lua._man._6_4_1` in the Hammerspoon console). If the `value` key is not set, than this key is ignored.
---        * `invert`                 -- a boolean, default false, specifying inverted logic for the criteria result --- if this is true and the criteria matches, evaluate criteria as false; otherwise evaluate as true.
---
---    * an array table of one or more key-value tables as described immediately above; the element must be a positive match for all of the individual criteria tables specified (logical AND).
---
---  * This method is used by [hs.axuielement.searchCriteriaFunction](#searchCriteriaFunction) to create criteria functions compatible with [hs.axuielement:elementSearch](#elementSearch).
objectMT.matchesCriteria = function(self, criteria)
    if type(criteria) == "string" then
        criteria = { attribute = "AXRole", value = criteria }
    elseif type(criteria) == "table" and #criteria > 0 then
        local allStrings = true
        for _,v in ipairs(criteria) do
            if type(v) ~= "string" then
                allStrings = false
                break
            end
        end
        if allStrings then
            criteria = { attribute = "AXRole", value = criteria }
        end
    end

    assert(type(criteria) == "table", "expected table defining criteria")

    if #criteria == 0 then criteria = { criteria } end
    -- prior to this we've made no changes to a table that's been passed to us
    criteria = tableCopyNoMT(criteria)
    -- "clean" criteria tables to simplify actual evaluation
    local criteriaKeys = {
        attribute              = true,
        action                 = true,
        parameterizedAttribute = true,
        value                  = true,
        nilValue               = true,
        pattern                = true,
        invert                 = true,
    }

    for idx,thisCriteria in ipairs(criteria) do
        assert(
            type(thisCriteria) == "table",
            "expected table of tables defining criteria; found " .. type(thisCriteria) .. " at index " .. tostring(idx)
        )
        for k,_ in pairs(thisCriteria) do
            assert(criteriaKeys[k], tostring(k) .. " is not a recognized criteria key")
        end

        if thisCriteria.attribute then
            if type(thisCriteria.attribute) ~= "table" then thisCriteria.attribute = { thisCriteria.attribute } end
        end
        if thisCriteria.action then
            if type(thisCriteria.action) ~= "table" then thisCriteria.action = { thisCriteria.action } end
        end
        if thisCriteria.parameterizedAttribute then
            if type(thisCriteria.parameterizedAttribute) ~= "table" then thisCriteria.parameterizedAttribute = { thisCriteria.parameterizedAttribute } end
        end
        if thisCriteria.value then
            if type(thisCriteria.value) ~= "table" then thisCriteria.value = { thisCriteria.value } end
        end
    end

    -- now on to the actual evaluation
    local finalResult = true
    local aav = self:allAttributeValues(true)      or {}
    local apa = self:parameterizedAttributeNames() or {}
    local aan = self:actionNames()                 or {}

    for _,thisCriteria in ipairs(criteria) do
        local thisResult = true
        if thisCriteria.attribute then
            for _,v in ipairs(thisCriteria.attribute) do
                if type(aav[v]) == "nil" then
                    thisResult = false
                    break
                end
            end
        end
        if thisResult and thisCriteria.action then
            for _,v in ipairs(thisCriteria.action) do
                if not fnutils.contains(aan, v) then
                    thisResult = false
                    break
                end
            end
        end
        if thisResult and thisCriteria.parameterizedAttribute then
            for _,v in ipairs(thisCriteria.parameterizedAttribute) do
                if not fnutils.contains(apa, v) then
                    thisResult = false
                    break
                end
            end
        end

        if thisResult then
            if thisCriteria.value then
                for _,v in ipairs(thisCriteria.attribute) do
                    local ans, found = aav[v], false
                    for _, v2 in ipairs(thisCriteria.value) do
                        if type(v2) == "string" and type(ans) == "string" and thisCriteria.pattern then
                            found = ans:match(v2) and true or false
                        else
                            found = ans == v2
                        end
                        if found then break end
                    end
                    thisResult = found
                    if not thisResult then break end
                end
            elseif type(thisCriteria.nilValue) ~= "nil" then
                for _,v in ipairs(thisCriteria.attribute) do
                    thisResult = thisCriteria.nilValue == ((type(aav[v]) == "table") and (aav[v]._code == -25212))
                    if not thisResult then break end
                end
            end
        end

        if thisCriteria.invert then thisResult = not thisResult end
        finalResult = thisResult -- and finalResult, but logically it's the same without the additional code
        if not finalResult then break end
    end
    return finalResult
end

--- hs.axuielement.searchCriteriaFunction(criteria) -> function
--- Function
--- Returns a function for use with [hs.axuielement:elementSearch](#elementSearch) that uses [hs.axuielement:matchesCriteria](#matchesCriteria) with the specified criteria.
---
--- Parameters:
---  * `criteria` - a criteria definition as defined for the [hs.axuielement:matchesCriteria](#matchesCriteria) method.
---
--- Returns:
---  * a function which can be used as the `criteriaFunction` for [hs.axuielement:elementSearch](#elementSearch).
module.searchCriteriaFunction = function(...)
    local args = table.pack(...)
    return function(e) return e:matchesCriteria(table.unpack(args)) end
end

--- hs.axuielement:buildTree(callback, [depth], [withParents]) -> elementSearchObject
--- Method
--- Captures all of the available information for the accessibility object and its descendants and returns it in a table for inspection.
---
--- Parameters:
---  * `callback` - a required function which should expect two arguments: a `msg` string specifying how the search ended, and a table containing the recorded information. `msg` will be "completed" when the search has completed normally (or reached the specified depth) and will contain a string starting with "**" if it terminates early for some reason (see Notes: section for more information)
---  * `depth`    - an optional integer, default `math.huge`, specifying the maximum depth from the initial accessibility object that should be visited to identify descendant elements and their attributes.
---  * `withParents` - an optional boolean, default false, specifying whether or not an element's (or descendant's) attributes for `AXParent` and `AXTopLevelUIElement` should also be visited when identifying additional elements to include in the results table.
---
--- Returns:
---  * an elementSearchObject as described in [hs.axuielement:elementSearch](#elementSearch)
---
--- Notes:
--- * The format of the `results` table passed to the callback for this method is primarily for debugging and exploratory purposes and may not be arranged for easy programatic evaluation.
---
---  * This method is syntactic sugar for `hs.axuielement:elementSearch(callback, { objectOnly = false, asTree = true, [depth = depth], [includeParents = withParents] })`. Please refer to [hs.axuielement:elementSearch](#elementSearch) for details about the returned object and callback arguments.
objectMT.buildTree = function(self, callback, depth, withParents)
    return self:elementSearch(callback, nil, {
        objectOnly     = false,
        asTree         = true,
        depth          = depth or math.huge,
        includeParents = withParents and true or false,
    })
end

--- hs.axuielement:allDescendantElements(callback, [withParents]) -> elementSearchObject
--- Method
--- Query the accessibility object for all child accessibility objects and their descendants
---
--- Parameters:
---  * `callback`    - a required function which should expect two arguments: a `msg` string specifying how the search ended, and a table containing the discovered descendant elements. `msg` will be "completed" when the traversal has completed normally and will contain a string starting with "**" if it terminates early for some reason (see Notes: section for more information)
---  * `withParents` - an optional boolean, default false, indicating that the parent of objects (and their descendants) should be collected as well.
---
--- Returns:
---  * an elementSearchObject as described in [hs.axuielement:elementSearch](#elementSearch)
---
--- Notes:
---  * This method is syntactic sugar for `hs.axuielement:elementSearch(callback, { [includeParents = withParents] })`. Please refer to [hs.axuielement:elementSearch](#elementSearch) for details about the returned object and callback arguments.
objectMT.allDescendantElements = function(self, callback, withParents)
    return self:elementSearch(callback, nil, { includeParents = withParents and true or false })
end


-- used for metamethods on hs.axuielement:elementSearch results
local elementFilterHamster = function(self, elementFilterObject)
    local efoMT = getmetatable(elementFilterObject)
    local state = efoMT._state

    local criteria    = state.criteria
    local objectsOnly = state.objectsOnly

    local results     = elementFilterObject

    local criteriaEmpty = not criteria

    for _,v in ipairs(self) do
        if state.cancel then break end
        if state.callback and coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore

        state.visited = state.visited + 1
        local addThis = criteriaEmpty or criteria(objectsOnly and v or v._element)
        if addThis then
            state.matched = state.matched + 1
            table.insert(results, v)
        end
    end
    if not state.cancel then state.msg = "completed" end

    return results
end

local elementSearchResultsFilter
elementSearchResultsFilter = function(self, criteria, callback)
    assert(
        type(criteria) == "function" or (getmetatable(criteria) or {}).__call, "expected function for criteria"
    )

    if callback then
        assert(
            type(callback) == "function" or (getmetatable(callback) or {}).__call, "expected function for filter callback"
        )
    end

    local state = {
        cancel      = false,
        callback    = callback,
        criteria    = criteria,
        objectsOnly = self[1] and (getmetatable(self[1]) == objectMT),
        matched     = 0,
        visited     = 0,
        started     = os.time(),
        finished    = nil,
    }

    local elementFilterObject = setmetatable({}, {
        _state = state,
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
            filter = function(_, ...)
                local efoMT = getmetatable(_)
                if not callback or efoMT._state.finished then
                    return elementSearchResultsFilter(_, ...)
                else
                    error("new filter cannot be applied while search or filter currently in progress", 2)
                end
            end,
        },
        __tostring = function(_)
            return USERDATA_TAG .. ".filterObject " .. tostring(self):match("%(.+%)$")
        end,
-- For now, not requiring that they capture this value to prevent collection.
--         __gc = function(_)
--             if not state.finished then
--                 _:cancel("gc on elementSearchObject object")
--             end
--         end,
    })


    if callback then
        local filterCoroutine
        filterCoroutine = coroutine.wrap(function()
            local results = elementFilterHamster(self, elementFilterObject)
            state.finished = os.time() - state.started
            callback(state.msg or "completed", results)
            filterCoroutine = nil -- ensure garbage collection doesn't happen until after we're done
        end)
        filterCoroutine()

        return elementFilterObject
    else
        return elementFilterHamster(self, elementFilterObject)
    end
end

-- used by hs.axuielement:elementSearch to do the heavy lifting. The search performed is a breadth first search.
local elementSearchHamsterBF = function(elementSearchObject)
    local esoMT = getmetatable(elementSearchObject)
    local self, state = esoMT._self, esoMT._state

    local queue   = esoMT._queue or { self }
    local depth   = esoMT._depth or 0
    -- allows use of userdata as key in hash table even though different userdata can refer to same object
    local seen    = esoMT._seen or setmetatable({ [self] = {} }, { -- capture initial self
                                      __index = function(_self, key)
                                          for k,v in pairs(_self) do
                                              if k == key then
                                                  -- speed up future searches. only works reliably if v is
                                                  -- table and future updates are to the table and not a
                                                  -- replacement of the table. pairs() will return each
                                                  -- copy, though, so its a trade off depending upon needs
                                                  rawset(_self, key, v)
                                                  return v
                                              end
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

    local results = elementSearchObject

    local criteria       = state.criteria
    local includeParents = state.namedMods.includeParents
    local maxDepth       = state.namedMods.depth
    local objectOnly     = state.namedMods.objectOnly
    local asTree         = state.namedMods.asTree

    local criteriaEmpty = not criteria

    local count, maxCount = 0, state.namedMods.count

    while #queue > 0 do
        if state.cancel or maxDepth < depth or count == maxCount then break end

        if state.callback and coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore

        local element = table.remove(queue, 1)
        if getmetatable(element) == objectMT then
            local aav = element:allAttributeValues(true) or {}
            state.visited = state.visited + 1
            if criteriaEmpty or criteria(element) then
                state.matched = state.matched + 1
                local keeping = objectOnly and element or seen[element]
                if not objectOnly then
                    -- store the table of details so we can replace the axuielement objects in the final results for attributes and children with their details
                    for k,v in pairs(aav) do keeping[k] = v end
                    keeping._element                 = element
                    keeping._actions                 = element:actionNames()
                    keeping._attributes              = element:attributeNames()
                    keeping._parameterizedAttributes = element:parameterizedAttributeNames()
                end
                table.insert(results, keeping)
                count = count + 1
            end
            if type(queue[#queue]) ~= "table" then table.insert(queue, {}) end
            local nxtLvlQueue = queue[#queue]

            -- most are in AXChildren, but a handful aren't, and a few are even nested in subtables (e.g. AXSections)
            local newChildren = {}
            for k,v in pairs(aav) do
                if includeParents or not fnutils.contains(parentLabels, k) then
                    if not (type(v) == "table" and v._code and v.error) then -- skip error tables
                        table.insert(newChildren, v)
                    end
                end
            end
            while #newChildren > 0 do
                if state.callback and coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore
                local potential = table.remove(newChildren, 1)
                if getmetatable(potential) == objectMT then
                    if not seen[potential] then
                        seen[potential] = {}
                        table.insert(nxtLvlQueue, potential)
                    end
                elseif type(potential) == "table" then
                    for _,v in pairs(potential) do table.insert(newChildren, v) end
                end
            end

        elseif type(element) == "table" then
            queue = element
            depth = depth + 1
        end
    end

    if not state.cancel then
        state.msg = ((#queue == 0) or (maxDepth < depth)) and "completed" or "countReached"
    end

    esoMT._depth = depth
    esoMT._queue = queue
    esoMT._seen  = seen

    if not objectOnly then -- convert values that are axuielements to their table stored in `seen`
        local deTableValue
        deTableValue = function(val)
            if getmetatable(val) == objectMT then
                return next(seen[val]) and seen[val] or val
            elseif type(val) == "table" then
                for k, v in pairs(val) do val[k] = deTableValue(v) end
            end
            return val
        end

        for _, element in ipairs(results) do
            for key, value in pairs(element) do
                if state.callback and coroutine.isyieldable() then coroutine.applicationYield() end -- luacheck: ignore

                if not key:match("^_") then -- skip our collections of actions, etc. and the element itself
                    element[key] = deTableValue(value)
                end
            end
        end
    end

    -- asTree is only valid (and in fact only works) if we captured all elements from the starting node and recorded their details
    if asTree and criteriaEmpty and not objectOnly then results = results[1] end

    return results, count
end

--- hs.axuielement:elementSearch(callback, [criteria], [namedModifiers]) -> elementSearchObject
--- Method
--- Search for and generate a table of the accessibility elements for the attributes and descendants of this object based on the specified criteria.
---
--- Parameters:
---  * `callback`       - a (usually) required function which will receive the results of this search. The callback should expect three arguments and return none. The arguments to the callback function will be `msg`, a string specifying how the search ended and `results`, the elementSearchObject containing the requested results, and the number of items added to the results (see `count` in `namedModifiers`). `msg` will be "completed" if the search completes normally, or a string starting with "**" if it is terminated early (see Returns: and Notes: for more details).
---  * `criteria`       - an optional function which should accept one argument (the current element being examined) and return true if it should be included in the results or false if it should be rejected. See [hs.axuielement.searchCriteriaFunction](#searchCriteriaFunction) to create a search function that uses [hs.axuielement:matchesCriteria](#matchesCriteria) for evaluation.
---  * `namedModifiers` - an optional table specifying key-value pairs that further modify or control the search. This table may contain 0 or more of the following keys:
---    * `count`          - an optional integer, default `math.huge`, specifying the maximum number of matches to collect before ending the search and invoking the callback. You can continue the search to find additional elements by invoking `elementSearchObject:next()` (described below in the `Returns` section) on the return value of this method, or on the results argument passed to the callback.
---    * `depth`          - an optional integer, default `math.huge`, specifying the maximum number of steps (descendants) from the initial accessibility element the search should visit. If you know that your desired element(s) are relatively close to your starting element, setting this to a lower value can significantly speed up the search.
---
---    * The following are also recognized, but may impact the speed of the search, the responsiveness of Hammerspoon, or the format of the results in ways that limit further filtering and are not recommended except when you know that you require them:
---      * `asTree`         - an optional boolean, default false, and ignored if `criteria` is specified and non-empty, `objectOnly` is true, or `count` is specified. This modifier specifies whether the search results should return as an array table of tables containing each element's details (false) or as a tree where in which the root node details are the key-value pairs of the returned table and descendant elements are likewise described in subtables attached to the attribute name they belong to (true). This format is primarily for debugging and exploratory purposes and may not be arranged for easy programatic evaluation.
---      * `includeParents` - a boolean, default false, specifying whether or not parent attributes (`AXParent` and `AXTopLevelUIElement`) should be examined during the search. Note that in most cases, setting this value to true will end up traversing the entire Accessibility structure for the target application and may significantly slow down the search.
---      * `noCallback`     - an optional boolean, default false, and ignored if `callback` is not also nil, allowing you to specify nil as the callback when set to true. This feature requires setting this named argumennt to true *and* specifying the callback field as nil because starting a query from an element with a lot of descendants **WILL** block Hammerspoon and slow down the responsiveness of your computer (I've seen blocking for over 5 minutes in extreme cases) and should be used *only* when you know you are starting from close to the end of the element heirarchy.
---      * `objectOnly`     - an optional boolean, default true, specifying whether each result in the final table will be the accessibility element discovered (true) or a table containing details about the element include the attribute names, actions, etc. for the element (false). This latter format is primarily for debugging and exploratory purposes and may not be arranged for easy programatic evaluation.
---
--- Returns:
---  * an elementSearchObject which contains metamethods allowing you to check to see if the process has completed and cancel it early if desired. The methods include:
---    * `elementSearchObject:cancel([reason])` - cancels the current search and invokes the callback with the partial results already collected. If you specify `reason`, the `msg` argument for the callback will be `** <reason>`; otherwise it will be "** cancelled".
---    * `elementSearchObject:isRunning()`      - returns true if the search is currently ongoing or false if it has completed or been cancelled.
---    * `elementSearchObject:matched()`        - returns an integer specifying the number of elements which have already been found that meet the specified criteria function.
---    * `elementSearchObject:runTime()`        - returns an integer specifying the number of seconds spent performing this search. Note that this is *not* an accurate measure of how much time a given search will always take because the time will be greatly affected by how much other activity is occurring within Hammerspoon and on the users computer. Resuming a cancelled search or a search which invoked the callback because it reached `count` items with the `next` method (descibed below) will cause this number to begin increasing again to provide a cumulative total of time spent performing the search; time between when the callback is invoked and the `next` method is invoked is not included.
---    * `elementSearchObject:visited()`        - returns an integer specifying the number of elements which have been examined during the search so far.
---
---    * If `asTree` is false or not specified, the following additional methods will be available:
---      * `elementSearchObject:filter(criteria, [callback]) -> filterObject`
---        * returns a new table containing elements in the search results that match the specified criteria.
---          * `criteria`  - a required function which should accept one argument (the current element being examined) and return true if it should be included in the results or false if it should be rejected. See [hs.axuielement.searchCriteriaFunction](#searchCriteriaFunction) to create a search function that uses [hs.axuielement:matchesCriteria](#matchesCriteria) for evaluation.
---          * `callback`  - an optional callback which should expect two arguments and return none. If a callback is specified, the callback will receive two arguments, a msg indicating how the callback ended (the message format matches the style defined for this method) and the filterObject which contains the matching elements.
---        * The filterObject returned by this method and passed to the callback, if defined, will support the following methods as defined here: `cancel`, `filter`, `isRunning`, `matched`, `runTime`, and `visited`.
---      * `elementSearchObject:next()` - if the search was cancelled or reached the count of matches specified, this method will continue the search where it left off. The elementSearchObject returned when the callback is next invoked will have up to `count` items added to the existing results (calls to `next` are cummulative for the total results captured in the elementSearchObject). The third ardument to the callback will be the number of items *added* to the search results, not the number of items *in* the search results.
---
--- Notes:
---  * This method utilizes coroutines to keep Hammerspoon responsive, but may be slow to complete if `includeParents` is true, if you do not specify `depth`, or if you start from an element that has a lot of descendants (e.g. the application element for a web browser). This is dependent entirely upon how many active accessibility elements the target application defines and where you begin your search and cannot reliably be determined up front, so you may need to experiment to find the best balance for your specific requirements.
---
--- * The search performed is a breadth-first search, so in general earlier elements in the results table will be "closer" in the Accessibility hierarchy to the starting point than later elements.
---
--- * The `elementSearchObject` returned by this method and the results passed in as the second argument to the callback function are the same object -- you can use either one in your code depending upon which makes the most sense. Results that match the criteria function are added to the `elementSearchObject` as they are found, so if you examine the object/table returned by this method and determine that you have located the element or elements you require before the callback has been invoked, you can safely invoke the cancel method to end the search early.
---
--- * If `objectsOnly` is specified as false, it may take some time after `cancel` is invoked for the mapping of element attribute tables to the descendant elements in the results set -- this is a by product of the need to iterate through the results to match up all of the instances of each element to it's attribute table.
---
--- * [hs.axuielement:allDescendantElements](#allDescendantElements) is syntactic sugar for `hs.axuielement:elementSearch(callback, { [includeParents = withParents] })`
--- * [hs.axuielement:buildTree](#buildTree) is syntactic sugar for `hs.axuielement:elementSearch(callback, { objectOnly = false, asTree = true, [depth = depth], [includeParents = withParents] })`
objectMT.elementSearch = function(self, callback, criteria, namedModifiers)
    local namedModifierDefaults = {
        includeParents = false,
        depth          = math.huge,
        objectOnly     = true,
        asTree         = false,
        noCallback     = false,
        count          = math.huge,
    }

    -- check to see if criteria left off and second arg is actually the namedModifiers table
    if type(namedModifiers) == "nil" and type(criteria) == "table" and not (getmetatable(criteria) or {}).__call then
        -- verify criteria "table" is actually namedMods and not a mistake on the users part (esp since we used to take a table
        -- for criteria)
        local isGoodForNM = true
        for k,_ in pairs(criteria) do
            if type(namedModifierDefaults[k]) == "nil" then
                isGoodForNM = false
                break
            end
        end
        if isGoodForNM then
            criteria, namedModifiers = nil, criteria
        end -- else let error out for bad criteria below
    end

    namedModifiers = namedModifiers or {}
    -- set defaults in namedModifiers for keys not provided
    if namedModifiers.count then namedModifiers.asTree = false end
    for k,v in pairs(namedModifierDefaults) do
        if type(namedModifiers[k]) == "nil" then
            namedModifiers[k] = v
        end
    end

    if not (namedModifiers.noCallback and callback == nil) then
        assert(
            type(callback) == "function" or (getmetatable(callback) or {}).__call,
            "elementSearch requires a callback function"
        )
    end

    if criteria then
        assert(
            type(criteria) == "function" or (getmetatable(criteria) or {}).__call,
            "criteria must be a function, if specified"
        )
    end

    local state = {
        cancel    = false,
        callback  = callback,
        criteria  = criteria,
        namedMods = namedModifiers,
        matched   = 0,
        visited   = 0,
        started   = os.time(),
        finished  = nil,
    }
    local elementSearchObject = setmetatable({}, {
        _state  = state,
        _self   = self,

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
            return USERDATA_TAG .. ".elementSearchObject " .. tostring(self):match("%(.+%)$")
        end,
-- For now, not requiring that they capture this value to prevent collection.
--         __gc = function(_)
--             if not state.finished then
--                 _:cancel("gc on elementSearchObject object")
--             end
--         end,
    })

    local esoMT = getmetatable(elementSearchObject)
    if not namedModifiers.asTree then
        esoMT.__index.filter = elementSearchResultsFilter -- make sure to document that results table is *new* with only filter method carrying over
        esoMT.__index.next = function(_)
            local nxtState = getmetatable(_)._nxtState
            if not callback or nxtState.finished then
                if nxtState.msg ~= "completed" then
                    nxtState.started  = os.time() - nxtState.finished
                    nxtState.finished = nil
                    nxtState.cancel   = nil
                    nxtState.msg      = nil
                    if callback then
                        local searchCoroutine
                        searchCoroutine = coroutine.wrap(function()
                            local results, countAdded = elementSearchHamsterBF(_)
                            nxtState.finished = os.time() - nxtState.started
                            callback(nxtState.msg, results, countAdded)
                            searchCoroutine = nil -- ensure garbage collection doesn't happen until after we're done
                        end)
                        searchCoroutine()

                        return _
                    else
                        return elementSearchHamsterBF(_)
                    end
                else
                    return nil
                end
            else
                error("next only available when search not in progress", 2)
            end
        end
    end

    if callback then
        local searchCoroutine
        searchCoroutine = coroutine.wrap(function()
            local results, countAdded = elementSearchHamsterBF(elementSearchObject)
            state.finished = os.time() - state.started
            callback(state.msg, results, countAdded)
            searchCoroutine = nil -- ensure garbage collection doesn't happen until after we're done
        end)
        searchCoroutine()

        return elementSearchObject
    else
        return elementSearchHamsterBF(elementSearchObject)
    end
end

local _applicationElement = module.applicationElement
module.applicationElement = function(obj)
    if type(obj) == "string" or type(obj) == "number" then
        for _,v in ipairs(table.pack(application.find(obj))) do
            if getmetatable(v) == hs.getObjectMetatable("hs.application") then
                return _applicationElement(v)
            end
        end
    end
    return _applicationElement(obj)
end

local _windowElement = module.windowElement
module.windowElement = function(obj)
    if type(obj) == "string" or type(obj) == "number" then
        return _windowElement(window.find(obj))
    else
        return _windowElement(obj)
    end
end

-- Return Module Object --------------------------------------------------

return module
