--- === hs.spotlight ===
---
--- This module allows Hammerspoon to preform Spotlight metadata queries.
---
--- This module will only be able to perform queries on volumes and folders which are not blocked by the Privacy settings in the System Preferences Spotlight panel.
---
--- A Spotlight query consists of two phases: an initial gathering phase where information currently in the Spotlight database is collected and returned, and a live-update phase which occurs after the gathering phase and consists of changes made to the Spotlight database, such as new entries being added, information in existing entries changing, or entities being removed.
---
--- The syntax for Spotlight Queries is beyond the scope of this module's documentation. It is a subset of the syntax supported by the Objective-C NSPredicate class.  Some references for this syntax can be found at:
---    * https://developer.apple.com/library/content/documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html
---    * https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html
---
--- Depending upon the callback messages enabled with the [hs.spotlight:callbackMessages](#callbackMessages) method, your callback assigned with the [hs.spotlight:setCallback](#setCallback) method, you can determine the query phase by noting which messages you have received.  During the initial gathering phase, the following callback messages may be observed: "didStart", "inProgress", and "didFinish".  Once the initial gathering phase has completed, you will only observe "didUpdate" messages until the query is stopped with the [hs.spotlight:stop](#stop) method.
---
--- You can also check to see if the initial gathering phase is in progress with the [hs.spotlight:isGathering](#isGathering) method.
---
--- You can access the individual results of the query with the [hs.spotlight:resultAtIndex](#resultAtIndex) method. For convenience, metamethods have been added to the spotlightObject which make accessing individual results easier:  an individual spotlightItemObject may be accessed from a spotlightObject by treating the spotlightObject like an array; e.g. `spotlightObject[n]` will access the n'th spotlightItemObject in the current results.

--- === hs.spotlight.group ===
---
--- This sub-module is used to access results to a spotlightObject query which have been grouped by one or more attribute values.
---
--- A spotlightGroupObject is a special object created when you specify one or more grouping attributes with [hs.spotlight:groupingAttributes](#groupingAttributes). Spotlight items which match the Spotlight query and share a common value for the specified attribute will be grouped in objects you can retrieve with the [hs.spotlight:groupedResults](#groupedResults) method. This method returns an array of spotlightGroupObjects.
---
--- For each spotlightGroupObject you can identify the attribute and value the grouping represents with the [hs.spotlight.group:attribute](#attribute) and [hs.spotlight.group:value](#value) methods.  An array of the results which belong to the group can be retrieved with the [hs.spotlight.group:resultAtIndex](#resultAtIndex) method.  For convenience, metamethods have been added to the spotlightGroupObject which make accessing individual results easier:  an individual spotlightItemObject may be accessed from a spotlightGroupObject by treating the spotlightGroupObject like an array; e.g. `spotlightGroupObject[n]` will access the n'th spotlightItemObject in the grouped results.

--- === hs.spotlight.item ===
---
--- This sub-module is used to access the individual results of a spotlightObject or a spotlightGroupObject.
---
--- Each Spotlight item contains attributes which you can access with the [hs.spotlight.item:valueForAttribute](#valueForAttribute) method. An array containing common attributes for the type of entity the item represents can be retrieved with the [hs.spotlight.item:attributes](#attributes) method, however this list of attributes is usually not a complete list of the attributes available for a given spotlightItemObject. Many of the known attribute names are included in the `hs.spotlight.commonAttributeKeys` constant array, but even this is not an exhaustive list -- an application may create and assign any key it wishes to an entity for inclusion in the Spotlight metadata database.
---
--- For convenience, metamethods have been added to the spotlightItemObjects as a shortcut to the [hs.spotlight.item:valueForAttribute](#valueForAttribute) method; e.g. you can access the value of a specific attribute by treating the attribute as a key name: `spotlightItemObject.kMDItemPath` will return the path to the entity the spotlightItemObject refers to.

local USERDATA_TAG = "hs.spotlight"
local module       = require("hs.libspotlight")
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)
local itemObjMT    = hs.getObjectMetatable(USERDATA_TAG .. ".item")
local groupObjMT   = hs.getObjectMetatable(USERDATA_TAG .. ".group")

require("hs.sharing") -- get NSURL helper

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.definedSearchScopes = ls.makeConstantsTable(module.definedSearchScopes)
table.sort(module.commonAttributeKeys)
module.commonAttributeKeys = ls.makeConstantsTable(module.commonAttributeKeys)

--- hs.spotlight:searchScopes([scope]) -> table | spotlightObject
--- Method
--- Get or set the search scopes allowed for the Spotlight query.
---
--- Parameters:
---  * `scope` - an optional table or list of items specifying the search scope for the Spotlight query.  Defaults to an empty array, specifying that the search is not limited in scope.
---
--- Returns:
---  * if an argument is provided for `scope`, returns the spotlightObject; otherwise returns a table containing the current search scopes.
---
--- Notes:
---  * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
---
---  * Each item listed in the `scope` table may be a string or a file URL table as described in documentation for the `hs.sharing.URL` and `hs.sharing.fileURL` functions.
---    * if an item is a string and matches one of the values in the [hs.spotlight.definedSearchScopes](#definedSearchScopes) table, then the scope for that item will be added to the valid search scopes.
---    * if an item is a string and does not match one of the predefined values, it is treated as a path on the local system and will undergo tilde prefix expansion befor being added to the search scopes (i.e. "~/" will be expanded to "/Users/username/").
---    * if an item is a table, it will be treated as a file URL table.
local searchScopes = objectMT.searchScopes
objectMT.searchScopes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return searchScopes(self)
    elseif args.n == 1 then
        return searchScopes(self, ...)
    else
        args.n = nil
        return searchScopes(self, args)
    end
end

--- hs.spotlight:callbackMessages([messages]) -> table | spotlightObject
--- Method
--- Get or specify the specific messages that should generate a callback.
---
--- Parameters:
---  * `messages` - an optional table or list of items specifying the specific callback messages that will generate a callback.  Defaults to { "didFinish" }.
---
--- Returns:
---  * if an argument is provided, returns the spotlightObject; otherwise returns the current values
---
--- Notes:
---  * Valid messages for the table are: "didFinish", "didStart", "didUpdate", and "inProgress".  See [hs.spotlight:setCallback](#setCallback) for more details about the messages.
local callbackMessages = objectMT.callbackMessages
objectMT.callbackMessages = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return callbackMessages(self)
    elseif args.n == 1 then
        return callbackMessages(self, ...)
    else
        args.n = nil
        return callbackMessages(self, args)
    end
end

--- hs.spotlight:groupingAttributes([attributes]) -> table | spotlightObject
--- Method
--- Get or set the grouping attributes for the Spotlight query.
---
--- Parameters:
---  * `attributes` - an optional table or list of items specifying the grouping attributes for the Spotlight query.  Defaults to an empty array.
---
--- Returns:
---  * if an argument is provided, returns the spotlightObject; otherwise returns the current values
---
--- Notes:
---  * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
---  * Setting this property will increase CPU and memory usage while performing the Spotlight query.
---
---  * Thie method allows you to access results grouped by the values of specific attributes.  See `hs.spotlight.group` for more information on using and accessing grouped results.
---  * Note that not all attributes can be used as a grouping attribute.  In such cases, the grouped result will contain all results and an attribute value of nil.
local groupingAttributes = objectMT.groupingAttributes
objectMT.groupingAttributes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return groupingAttributes(self)
    elseif args.n == 1 then
        return groupingAttributes(self, ...)
    else
        args.n = nil
        return groupingAttributes(self, args)
    end
end

--- hs.spotlight:valueListAttributes([attributes]) -> table | spotlightObject
--- Method
--- Get or set the attributes for which value list summaries are produced for the Spotlight query.
---
--- Parameters:
---  * `attributes` - an optional table or list of items specifying the attributes for which value list summaries are produced for the Spotlight query.  Defaults to an empty array.
---
--- Returns:
---  * if an argument is provided, returns the spotlightObject; otherwise returns the current values
---
--- Notes:
---  * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
---  * Setting this property will increase CPU and memory usage while performing the Spotlight query.
---
---  * This method allows you to specify attributes for which you wish to gather summary information about.  See [hs.spotlight:valueLists](#valueLists) for more information about value list summaries.
---  * Note that not all attributes can be used as a value list attribute.  In such cases, the summary for the attribute will specify all results and an attribute value of nil.
local valueListAttributes = objectMT.valueListAttributes
objectMT.valueListAttributes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return valueListAttributes(self)
    elseif args.n == 1 then
        return valueListAttributes(self, ...)
    else
        args.n = nil
        return valueListAttributes(self, args)
    end
end

--- hs.spotlight:sortDescriptors([attributes]) -> table | spotlightObject
--- Method
--- Get or set the sorting preferences for the results of a Spotlight query.
---
--- Parameters:
---  * `attributes` - an optional table or list of items specifying sort descriptors which affect the sorting order of results for a Spotlight query.  Defaults to an empty array.
---
--- Returns:
---  * if an argument is provided, returns the spotlightObject; otherwise returns the current values
---
--- Notes:
---  * Setting this property while a query is running stops the query and discards the current results. The receiver immediately starts a new query.
---
---  * A sort descriptor may be specified as a string or as a table of key-value pairs.  In the case of a string, the sort descriptor will sort items in an ascending manner.  When specified as a table, at least the following keys should be specified:
---    * `key`       - a string specifying the attribute to sort by
---    * `ascending` - a boolean, default true, specifying whether the sort order should be ascending (true) or descending (false).
---
---  * This method attempts to specify the sorting order of the results returned by the Spotlight query.
---  * Note that not all attributes can be used as an attribute in a sort descriptor.  In such cases, the sort descriptor will have no affect on the order of returned items.
local sortDescriptors = objectMT.sortDescriptors
objectMT.sortDescriptors = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return sortDescriptors(self)
    elseif args.n == 1 then
        return sortDescriptors(self, ...)
    else
        args.n = nil
        return sortDescriptors(self, args)
    end
end

objectMT.__index = function(self, key)
    if objectMT[key] then return objectMT[key] end
    if math.type(key) == "integer" and key > 0 and key <= self:count() then
        return self:resultAtIndex(key)
    else
        return nil
    end
end

objectMT.__call = function(self, cmd, ...)
    local currentlyRunning = self:isRunning()
    if table.pack(...).n > 0 then
        self:searchScopes(...):queryString(cmd)
    else
        self:queryString(cmd)
    end
    if not currentlyRunning then self:start() end
    return self
end

objectMT.__pairs = function(self)
    return function(_, k)
              if k == nil then
                  k = 1
              else
                  k = k + 1
              end
              local v = _[k]
              if v == nil then
                  return nil
              else
                  return k, v
              end
           end, self, nil
end

objectMT.__len = function(self)
    return self:count()
end

itemObjMT.__index = function(self, key)
    if itemObjMT[key] then return itemObjMT[key] end
    return self:valueForAttribute(key)
end

itemObjMT.__pairs = function(self)
    local keys = self:attributes()
    return function()
              local k = table.remove(keys)
              if k then
                  return k, self:valueForAttribute(k)
              else
                  return nil
              end
           end, self, nil
end

-- no numeric indexes, so...
-- itemObjMT.__len = function(self) return 0 end

groupObjMT.__index = function(self, key)
    if groupObjMT[key] then return groupObjMT[key] end
    if math.type(key) == "integer" and key > 0 and key <= self:count() then
        return self:resultAtIndex(key)
    else
        return nil
    end
end

groupObjMT.__pairs = function(self)
    return function(_, k)
              if k == nil then
                  k = 1
              else
                  k = k + 1
              end
              local v = _[k]
              if v == nil then
                  return nil
              else
                  return k, v
              end
           end, self, nil
end

groupObjMT.__len = function(self)
    return self:count()
end

-- Return Module Object --------------------------------------------------

return module
