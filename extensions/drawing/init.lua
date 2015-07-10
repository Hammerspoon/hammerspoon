local module = require("hs.drawing.internal")
--- hs.drawing.color
--- Constant
--- This table contains various useful pre-defined colors:
---  * osx_red - The same red used for OS X window close buttons
---  * osx_green - The same green used for OS X window zoom buttons
---  * osx_yellow - The same yellow used for OS X window minimize buttons
---
--- Please feel free to submit additional useful colors :)
module.color = {
    ["osx_green"]   = { ["red"]=0.153,["green"]=0.788,["blue"]=0.251,["alpha"]=1 },
    ["osx_red"]     = { ["red"]=0.996,["green"]=0.329,["blue"]=0.302,["alpha"]=1 },
    ["osx_yellow"]  = { ["red"]=1.000,["green"]=0.741,["blue"]=0.180,["alpha"]=1 },
}

local fnutils = require("hs.fnutils")

local __tostring_for_tables = function(self)
    local result = ""
    local width = 0
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" and width < i:len() then width = i:len() end
    end
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" then
            result = result..string.format("%-"..tostring(width).."s %d\n", i, v)
        end
    end
    return result
end

module.fontTraits      = setmetatable(module.fontTraits,      { __tostring = __tostring_for_tables })
module.windowBehaviors = setmetatable(module.windowBehaviors, { __tostring = __tostring_for_tables })

local tmp = module.rectangle({})
local tmpMeta = getmetatable(tmp)

--- hs.drawing:setBehaviorByLabels(table) -> object
--- Method
--- Sets the window behaviors based upon the labels specified in the table provided.
---
--- Parameters:
---  * a table of label strings or numbers.  Recognized values can be found in `hs.drawing.windowBehaviors`.
---
--- Returns:
---  * The `hs.drawing` object
tmpMeta.setBehaviorByLabels = function(obj, stringTable)
    local newBehavior = 0
    for i,v in ipairs(stringTable) do
        local flag = tonumber(v) or module.windowBehaviors[v]
        newBehavior = newBehavior | flag
    end
    return obj:setBehavior(newBehavior)
end

--- hs.drawing:behaviorAsLabels() -> table
--- Method
--- Returns a table of the labels for the current behaviors of the object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Returns a table of the labels for the current behaviors with respect to Spaces and Exposé for the object.
tmpMeta.behaviorAsLabels = function(obj)
    local results = {}
    local behaviorNumber = obj:behavior()

    if behaviorNumber ~= 0 then
        for i, v in pairs(module.windowBehaviors) do
            if type(i) == "string" then
                if (behaviorNumber & v) > 0 then table.insert(results, i) end
            end
        end
    else
        table.insert(results, module.windowBehaviors[0])
    end
    return results
end

tmp:delete()
tmp = nil

return module
