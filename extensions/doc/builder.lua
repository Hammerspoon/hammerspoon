
--- === hs.doc.builder ===
---
--- Builds documentation support files.  Still experimental

local module = {}
local json    = require("hs.json")
local fnutils = require("hs.fnutils")

-- the ultimate goal with the following is to allow anyone who has *only* Hammerspoon to build
-- their own HTML web pages or Dash Docset that includes the core documentation and any third
-- party module's documentation in one result set.
--
-- Not all of the support is here yet because hs.httpserver.hsminweb needs a few more tweaks,
-- but this will form the basic tools for building the documentation from scratch.

local sections = {
-- sort order according to scripts/docs/templates/ext.html.erb
    Deprecated  = 1,
    Command     = 2,
    Constant    = 3,
    Variable    = 4,
    Function    = 5,
    Constructor = 6,
    Field       = 7,
    Method      = 8,
}

module.genComments = function(where)
    -- get the comments from the specified path(s)
    local text = {}
    if type(where) == "string" then where = { where } end
    for _, path in ipairs(where) do
        for _, file in ipairs(fnutils.split(hs.execute("find "..path.." -name \\*.lua -print -o -name \\*.m -print"), "[\r\n]")) do
            if file ~= "" then
                local comment, incomment = {}, false
                for line in io.lines(file) do
                    local aline = line:match("^%s*(.-)$")
                    if (aline:match("^%-%-%-") or aline:match("^///")) and not aline:match("^...[%-/]") then
                        incomment = true
                        table.insert(comment, aline:match("^... ?(.-)$"))
                    elseif incomment then
                        table.insert(text, comment)
                        comment, incomment = {}, false
                    end
                end
            end
        end
    end

    -- parse the comments into table form
    local mods, items = {}, {}
    for _, v in ipairs(text) do
        if v[1]:match("===") then

--  stripped_doc = "",

 -- a module definition block
            local newMod = {
                name       = v[1]:gsub("=", ""):match("^%s*(.-)%s*$"),
                desc       = (v[3] or "UNKNOWN DESC"):match("^%s*(.-)%s*$"),
                doc        = table.concat(v, "\n", 2, #v):match("^%s*(.-)%s*$"),
                items      = {},
                submodules = {},
                ["type"]   = "Module",
            }
            for k,v in pairs(sections) do newMod[k] = {} end
            table.insert(mods, newMod)
        else

--  notes = {...},
--  parameters = {...},
--  returns = {...},
--  stripped_doc = "",

            -- an item block
            local newItem = {
                ["type"]   = v[2],
                name       = nil,
                def        = v[1],
                signature  = v[1],
                desc       = (v[3] or "UNKNOWN DESC"):match("^%s*(.-)%s*$"),
                doc        = (table.concat(v, "\n", 3, #v) or "UNKNOWN DOC"):match("^%s*(.-)%s*$"),
                notes      = {},
                parameters = {},
                returns    = {},
            }
            local currentTarget = nil
            for theLine in ipairs(fnutils.split(newItem.doc, "\n")) do
                if theLine:match("^^%s*Parameters:%s*$") then
                    currentTarget = "parameters"
                elseif theLine:match("^^%s*Returns:%s*$") then
                    currentTarget = "returns"
                elseif theLine:match("^^%s*Notes:%s*$") then
                    currentTarget = "notes"
                else
                    if currentTarget then
                        table.insert(newItem[currentTarget], theLine)
                    else
                        hs.printf("~~ extraneous line in %s: %s", newItem.signature, theLine)
                    end
                end
            end
            table.insert(items, newItem)
        end
    end
    -- by reversing the order of the module names, sub-modules come before modules, allowing items to
    -- be properly assigned; otherwise, a.b.c might get put into a instead of a.b
    table.sort(mods, function(a, b) return b.name < a.name end)
    local seen = {}
    for _, i in ipairs(items) do
        local mod = nil
        for _, m in ipairs(mods) do
            if i.def:match("^"..m.name.."[%.:]") then
                mod = m
                i.name = i.def:match("^"..m.name.."[%.:]([%w%d_]+)")
                if not sections[i["type"]] then
                    error("error: unknown type "..i["type"].." in "..m.name.."."..i.name)
                end
                table.insert(m.items, i)
                table.insert(m[i["type"]], i)
                break
            end
        end
        if not mod then
            error("error: couldn't find module for "..i.def.." ("..i["type"]..") ("..i.doc..")")
        end
    end
    table.sort(mods, function(a, b) return a.name < b.name end)
    for _, v in ipairs(mods) do
        table.sort(v.items, function(a, b)
            if sections[a["type"]] ~= sections[b["type"]] then
                return sections[a["type"]] < sections[b["type"]]
            else
                return a["name"] < b["name"]
            end
        end)
    end
    -- populate submodules field for modules
    for i = 1, #mods, 1 do
        local parentName = mods[i].name
        for i2 = (i + 1), #mods, 1 do
            local subName = mods[i2].name:match("^" .. parentName .. "%.([^%.]+)$")
            if subName then table.insert(mods[i].submodules, subName) end
        end
    end
    return mods
end

module.genSQL = function(mods)
    if type(mods) == "string" then mods = module.genComments(mods) end
    local results = [[
CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);
CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);
]]
    for _, m in ipairs(mods) do
        for _, i in ipairs(m.items) do
            results = results.."INSERT INTO searchIndex VALUES (NULL, '"..m.name.."."..i.name.."', '"..i["type"].."', '"..m.name..".html#"..i.name.."');\n"
        end
        results = results.."INSERT INTO searchIndex VALUES (NULL, '"..m.name.."', 'Module', '"..m.name..".html');\n"
    end
    return results
end

module.genJSON = function(mods)
    if type(mods) == "string" then mods = module.genComments(mods) end
    return json.encode(mods, true)
end

module.commentsFromSource = function(src)
    return module.genComments{ src.."/extensions", src.."/Hammerspoon" }
end
