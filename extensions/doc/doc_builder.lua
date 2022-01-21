
--- === hs.doc.builder ===
---
--- Builds documentation support files.  Still experimental.
---
--- This submodule provides functions for mimicking the documentation generation processes used when generating the official Hammerspoon documentation.  The long term goal is to provide a mechanism for generating complete Hammerspoon documentation in all of its formats with only the Hammerspoon application and source files without any additional software required.
---
--- This submodule can be used to generate and maintain the documentation for Spoon bundles and can also be used to generate documentation for third-party modules as well.
---
--- Documentation for modules and spoons is expected to be embedded in the source code for the relevant object in specially formatted comment strings.  A very brief example of how to format documentation can be found at https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#documentation, but a better treatment is planned.
---
--- Most of this submodule should be considered at the "Proof of Concept" stage and will require some additional work on your part to generate useful documentation in HTML, Markdown, or Docset formats.  This is expected to change in the future.

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

--- hs.doc.builder.genComments(path, [recurse]) -> table
--- Function
--- Generates a documentation table for Hammerspoon modules or Spoon bundles from the source files located in the path(s) provided.
---
--- Parameters:
---  * where - a string specifying a single path, or a table containing multiple strings specifying paths where source files should be examined to generate the documentation table.
---  * recurse - an optional boolean, default true, specifying whether or not files in sub-directories of the specified path should be examined for comment strings as well.
---
--- Returns:
---  * table - a table containing the documentation broken out into the key-value pairs used to generate documentation displayed by `hs.doc` and `hs.doc.hsdocs`.
---
--- Notes:
---  * Because Hammerspoon and all known currently available modules are coded in Objective-C and/or Lua, only files with the .m or .lua extension are examined in the provided path(s).  Please submit an issue (or pull request, if you modify this submodule yourself) at https://github.com/Hammerspoon if you need this to be changed for your addition.
module.genComments = function(where, recurse)
    -- get the comments from the specified path(s)
    local text = {}
    if type(where) == "string" then where = { where } end
    if type(recurse) == "nil" then recurse = true end
    local maxDepth = recurse and " -maxdepth 1" or ""
    for _, path in ipairs(where) do
        for _, file in ipairs(fnutils.split(hs.execute("find -L "..path..maxDepth.." -name \\*.lua -print -o -name \\*.m -print"), "[\r\n]")) do
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

--  stripped_doc = "", -- still need to figure out how its filled for modules, then test all of the new fields

             -- a module definition block
            local newMod = {
                name         = v[1]:gsub("=", ""):match("^%s*(.-)%s*$"),
                desc         = (v[3] or "UNKNOWN DESC"):match("^%s*(.-)%s*$"),
                doc          = table.concat(v, "\n", 2, #v):match("^%s*(.-)%s*$"),
                items        = {},
                submodules   = {},
                stripped_doc = {},
                ["type"]     = "Module",
            }
            for k,_ in pairs(sections) do newMod[k] = {} end
            table.insert(mods, newMod)
        else

            -- an item block
            local newItem = {
                ["type"]     = v[2],
                name         = nil,
                def          = v[1],
                signature    = v[1],
                desc         = (v[3] or "UNKNOWN DESC"):match("^%s*(.-)%s*$"),
                doc          = (table.concat(v, "\n", 3, #v) or "UNKNOWN DOC"):match("^%s*(.-)%s*$"),
                notes        = {},
                parameters   = {},
                returns      = {},
                stripped_doc = {},
            }
            local currentTarget = nil
            for _, theLine in ipairs(fnutils.split(newItem.doc, "\n")) do
                if theLine:match("^%s*Parameters:%s*$") then
                    currentTarget = "parameters"
                elseif theLine:match("^%s*Returns:%s*$") then
                    currentTarget = "returns"
                elseif theLine:match("^%s*Notes:%s*$") then
                    currentTarget = "notes"
                else
                    if currentTarget then
                        table.insert(newItem[currentTarget], theLine)
                    else
                        table.insert(newItem.stripped_doc, theLine)
--                        hs.printf("~~ extraneous line in %s: %s", newItem.signature, theLine)
                    end
                end
            end
            table.insert(items, newItem)
        end
    end
    -- by reversing the order of the module names, sub-modules come before modules, allowing items to
    -- be properly assigned; otherwise, a.b.c might get put into a instead of a.b
    table.sort(mods, function(a, b) return b.name < a.name end)
    for _, i in ipairs(items) do
        local mod = nil
        for _, m in ipairs(mods) do
            if i.def:match("^"..m.name.."[%.:]") then
                mod = m
                i.name = i.def:match("^"..m.name.."[%.:]([%w%d_]+)")
                if not sections[i["type"]] then
                    error("unknown type "..i["type"].." in "..m.name.."."..i.name)
                end
                table.insert(m.items, i)
                table.insert(m[i["type"]], i)
                break
            end
        end
        if not mod then
            error("couldn't find module for "..i.def.." ("..i["type"]..") ("..i.doc..")")
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

--- hs.doc.builder.genSQL(source) -> string
--- Function
--- Generates the SQL commands required for creating the search index when creating a docset of the documentation.
---
--- Parameters:
---  * source - the source to generate the SQL commands for.  If this is provided as a string, it is passed to [hs.doc.builder.genComments](#genComments) and the result is used.  If it is a table, then it is assumed to have already been generated by a call to [hs.doc.builder.genComments](#genComments).
---
--- Returns:
---  * string - the relevant SQL commands as a string
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

--- hs.doc.builder.genJSON(source) -> string
--- Function
--- Generates a JSON string representation of the documentation source specified. This is the format expected by `hs.doc` and `hs.doc.hsdoc` and is used to provide the built in documentation for Hammerspoon.
---
--- Parameters:
---  * source - the source to generate the JSON string for.  If this is provided as a string, it is passed to [hs.doc.builder.genComments](#genComments) and the result is used.  If it is a table, then it is assumed to have already been generated by a call to [hs.doc.builder.genComments](#genComments).
---
--- Returns:
---  * string - the JSON string representation of the documentation
---
--- Notes:
---  * If you have installed the `hs` command line tool (see `hs.ipc`), you can use the following to generate the `docs.json` file that is used to provide documentation for Hammerspoon Spoon bundles: `hs -c "hs.doc.builder.genJSON(\"$(pwd)\")" > docs.json`
---  * You can also use this to generate documentation for any third-party-modules you build, but you will have to register the documentation with `hs.doc.registerJSONFile` yourself -- it is not automatically loaded for you like it is for Spoons.
module.genJSON = function(mods)
    if type(mods) == "string" then mods = module.genComments(mods) end
    return json.encode(mods, true)
end

-- eventually this will be the starting point for generating your own local copy of the Hammerspoon documentation
module.commentsFromHammerspoonSource = function(src)
    return module.genComments{ src.."/extensions", src.."/Hammerspoon" }
end

return module
