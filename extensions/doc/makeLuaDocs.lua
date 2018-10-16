-- -[x] do separate parse of manual text for lua.man and lua.func so manual actually approximates real manual with function defs in chapters
-- -[x] instead of converting . to _ in func, create sub tables
-- -[x] same for man?  No, hs.doc then splits toc into submodules/modules
-- -[x] move func to root?
-- -[ ] a way to programmatically figure out SkipThese?

local http     = require("hs.http")
local inspect  = require("hs.inspect")
local timer    = require("hs.timer")
local json     = require("hs.json")

local verNum             = string.gsub(_VERSION,"Lua ","")
local luaDocsBaseURL     = "http://www.lua.org/manual/"..verNum.."/"
local destinationDocFile = "lua.json"

local luaPrefix          = "lua"
local manualPrefix       = luaPrefix.."._man"
local functionPrefix     = luaPrefix
local cAPIPrefix         = functionPrefix.."._C"


-- Known to be in lists or otherwise problematic

local SkipThese = {
    ["pdf-luaopen_base"] = true,
    ["pdf-luaopen_package"] = true,
    ["pdf-luaopen_coroutine"] = true,
    ["pdf-luaopen_string"] = true,
    ["pdf-luaopen_utf8"] = true,
    ["pdf-luaopen_table"] = true,
    ["pdf-luaopen_math"] = true,
    ["pdf-luaopen_io"] = true,
    ["pdf-luaopen_os"] = true,
    ["pdf-luaopen_debug"] = true,
    ["pdf-lualib.h"] = true,
    ["pdf-LUA_MASKCALL"] = true,
    ["pdf-LUA_MASKRET"] = true,
    ["pdf-LUA_MASKLINE"] = true,
    ["pdf-LUA_MASKCOUNT"] = true,
    ["pdf-io.stdin"] = true,
    ["pdf-io.stdout"] = true,
    ["pdf-io.stderr"] = true,
    ["pdf-LUA_HOOKCALL"] = true,
    ["pdf-LUA_HOOKRET"] = true,
    ["pdf-LUA_HOOKTAILCALL"] = true,
    ["pdf-LUA_HOOKLINE"] = true,
    ["pdf-LUA_HOOKCOUNT"] = true,
    ["pdf-LUA_MININTEGER"] = true,
    ["pdf-LUA_MAXINTEGER"] = true,
    ["pdf-LUA_OK"] = true,
    ["pdf-LUA_ERRRUN"] = true,
    ["pdf-LUA_ERRMEM"] = true,
    ["pdf-LUA_ERRERR"] = true,
    ["pdf-LUA_ERRGCMM"] = true,
    ["pdf-LUA_TNIL"] = true,
    ["pdf-LUA_TNUMBER"] = true,
    ["pdf-LUA_TBOOLEAN"] = true,
    ["pdf-LUA_TSTRING"] = true,
    ["pdf-LUA_TTABLE"] = true,
    ["pdf-LUA_TFUNCTION"] = true,
    ["pdf-LUA_TUSERDATA"] = true,
    ["pdf-LUA_TTHREAD"] = true,
    ["pdf-LUA_TLIGHTUSERDATA"] = true,
    ["pdf-LUA_OPADD"] = true,
    ["pdf-LUA_OPSUB"] = true,
    ["pdf-LUA_OPMUL"] = true,
    ["pdf-LUA_OPDIV"] = true,
    ["pdf-LUA_OPIDIV"] = true,
    ["pdf-LUA_OPMOD"] = true,
    ["pdf-LUA_OPPOW"] = true,
    ["pdf-LUA_OPUNM"] = true,
    ["pdf-LUA_OPBNOT"] = true,
    ["pdf-LUA_OPBAND"] = true,
    ["pdf-LUA_OPBOR"] = true,
    ["pdf-LUA_OPBXOR"] = true,
    ["pdf-LUA_OPSHL"] = true,
    ["pdf-LUA_OPSHR"] = true,
    ["pdf-LUA_OPEQ"] = true,
    ["pdf-LUA_OPLT"] = true,
    ["pdf-LUA_OPLE"] = true,
    ["pdf-LUA_ERRSYNTAX"] = true,
    ["pdf-LUA_RIDX_MAINTHREAD"] = true,
    ["pdf-LUA_RIDX_GLOBALS"] = true,
    ["pdf-LUAL_BUFFERSIZE"] = true,
    ["pdf-LUA_CPATH"] = true,
    ["pdf-LUA_CPATH_5_3"] = true,
    ["pdf-LUA_ERRFILE"] = true,
    ["pdf-LUA_INIT"] = true,
    ["pdf-LUA_INIT_5_3"] = true,
    ["pdf-LUA_MINSTACK"] = true,
    ["pdf-LUA_MULTRET"] = true,
    ["pdf-LUA_NOREF"] = true,
    ["pdf-LUA_PATH"] = true,
    ["pdf-LUA_PATH_5_3"] = true,
    ["pdf-LUA_REFNIL"] = true,
    ["pdf-LUA_REGISTRYINDEX"] = true,
    ["pdf-LUA_TNONE"] = true,
    ["pdf-LUA_USE_APICHECK"] = true,
    ["pdf-LUA_YIELD"] = true,
}

local LuaContents = nil
local LuaManual   = nil

local StripHTML = function(inString, showHR)
    showHR = showHR or false
    return inString:gsub("<([^>]+)>", function(c)
            local d = c:lower()
                if d == "code" or d == "/code" then return "`"
            elseif d == "li"                   then return " * "
            elseif d == "br"                   then return "\n"
            elseif d == "p"                    then return "\n"
            elseif d:match("^/?pre")           then return "\n~~~\n"
            elseif d:match("^/?h%d+")          then return "\n\n"
            elseif d == "hr" and showHR        then return "\n\n"..string.rep("-",80).."\n\n"
            else                                    return ""
            end
        end)
end

print("++ Initiating requests for "..luaDocsBaseURL.." and "..luaDocsBaseURL.."manual.html")

-- Issue a request for the contents page and for the manual page

http.asyncGet(luaDocsBaseURL,nil,function(rc, data, headers)
    if rc == 200 then
        LuaContents = data
    else
        if rc < 0 then
            print("++ Request failure for Contents:", rc, data)
        else
            print("++ Unable to retrieve Contents:",  rc, data, inspect(headers))
        end

        LuaContents = false
    end
end)

http.asyncGet(luaDocsBaseURL.."manual.html",nil,function(rc, data, headers)
    if rc == 200 then
        LuaManual = data
    else
        if rc < 0 then
            print("++ Request failure for Manual:",   rc, data)
        else
            print("++ Unable to retrieve Manual:",    rc, data, inspect(headers))
        end

        LuaManual = false
    end
end)

-- Wait until requests are done and then parse them

local waitForIt
waitForIt = timer.new(2, function()

    -- If we're not done yet, wait for another go around...
    if type(LuaContents) == "nil" or type(LuaManual) == "nil" then
        return
    end

    -- Since both are not nil, we've got our data... no need to recheck again.
    waitForIt:stop()

    -- If either is false, then we failed to get the data we need.
    if not (LuaContents and LuaManual) then
        print("++ Unable to parse manual due to request failure.")
        return
    end

print("++ Parsing manual...")

    -- Ok... parse away...

-- Identify keys from the table of contents

    local Keys -- comment out for debugging purposes
    Keys = {}
    for k,v in LuaContents:gmatch("<[aA][^\r\n]*%s+[hH][rR][eE][fF]%s*=%s*\"manual.html#([^\">]+)\"[^\r\n]*>([^<]+)</[aA][^\r\n]*>") do
        if not SkipThese[k] then
            if Keys[k] then
                table.insert(Keys[k].labels, v)
            else
                Keys[k] = {labels = {(http.convertHtmlEntities(v))}}
            end
        end
    end

    -- Introduction not marked as a target tag, so force it.
    if not Keys["1"] then Keys["1"] = { labels = {"1 – Introduction" }} end

    -- Trick builtin cleanup code into pasting Section 4's text into the c-api submodule section
    table.insert(Keys["4"].labels, "capi")

-- Get manual version first -- first pass we ignore keys that aren't numbers

    local a = 1
    local b, k
    local text, posTable = nil, nil

    while a < LuaManual:len() do
        a, b, k = LuaManual:find("[\r\n][^\r\n]*<[aA][^\r\n]*%s+[nN][aA][mM][eE]%s*=%s*\"([%d%.]+)\"[^\r\n]*>", a)
        if not a then
            a = LuaManual:len()
        else
            if Keys[k] then
                if posTable then
                    table.insert(posTable, a - 1)
                    local actualText, _ = StripHTML(LuaManual:sub(posTable[1], posTable[2]), true)
                    table.insert(text, (http.convertHtmlEntities(actualText)))
                end
                posTable         = {a}
                text             = {}
                Keys[k].manpos   = posTable
                Keys[k].mantext  = text
            --else
--                if not SkipThese[k] then print("++ No key found for '"..k.."', skipping...") end
            end
            a = b + 1
        end
    end
    if not next(text) then
        table.insert(posTable, LuaManual:len() - 1)
        local actualText, _ = StripHTML(LuaManual:sub(posTable[1], posTable[2]), true)
        table.insert(text, (http.convertHtmlEntities(actualText)))
    end

-- Get function version -- this pass we capture for all keys that were found in the contents
-- This time we'll also post about keys from the Text that weren't found in the contents... probably
-- ignorable, as they're likely links within the manual itself to lists already included in a manual section,
-- but post them just in case I need to look for them later if the format changes.

    a = 1
    text, posTable = nil, nil

    while a < LuaManual:len() do
        a, b, k = LuaManual:find("[\r\n][^\r\n]*<[aA][^\r\n>]*%s+[nN][aA][mM][eE]%s*=%s*\"([^\r\n\">]+)\"[^\r\n>]*>", a)
        if not a then
            a = LuaManual:len()
        else
            if Keys[k] then
                if posTable then
                    table.insert(posTable, a - 1)
                    local actualText, _ = StripHTML(LuaManual:sub(posTable[1], posTable[2]))
                    table.insert(text, (http.convertHtmlEntities(actualText)))
                end
                posTable         = {a}
                text             = {}
                Keys[k].funcpos  = {func = posTable}
                Keys[k].functext = text
            else
                if not SkipThese[k] then print("++ No key found for '"..k.."', probably safe...") end
            end
            a = b + 1
        end
    end
    if not next(text) then
        table.insert(posTable, LuaManual:len() - 1)
        local actualText, _ = StripHTML(LuaManual:sub(posTable[1], posTable[2]))
        table.insert(text, (http.convertHtmlEntities(actualText)))
    end

-- Turn into JSON for hs.doc

    local docRoots -- comment out for debugging purposes
    docRoots = {
        manual = {
            name  = manualPrefix,
            desc  = _VERSION.." manual",
            doc   = "Select a section from the ".._VERSION.." manual by prefacing it's number with and replacing all periods with an '_'; e.g. Section 6.4 would be _6_4.",
            items = {}
        },
        capi = {
            name  = cAPIPrefix,
            desc  = _VERSION.." C API",
            doc   = "C API for external library integration.",
            items = {}
        },
        builtin = {
            name  = luaPrefix,
            desc  = _VERSION.." Documentation",
            doc   = [[
Built in ]].._VERSION..[[ functions and variables.

The text for this documentation is originally from ]]..luaDocsBaseURL..[[ but has been programmatically parsed and rearranged for use with the Hammerspoon internal documentation system.  Any errors, mistakes, or omissions are likely the result of this processing and is in no way a reflection on Lua.org or their work.  If in doubt about anything presented in this lua section of the Hammerspoon documentation, please check the above web site for the authoritative answer.
]],
            items = {}
        },
    }
    for i,v in pairs(Keys) do
        for _,bb in ipairs(v.labels) do
            local destItems, itemDef, theText
            if bb:match("^%d+") then                                         -- part of the manual
                destItems = docRoots.manual.items
                itemDef = {
                    type="manual",
                    name = "_"..i:gsub("%.","_"),
                    def = bb,
                }
                if v.mantext then theText = v.mantext[1] end
            else
                if bb:match("^_") then                                       -- builtin variable
                    destItems = docRoots.builtin.items
                    itemDef = {
                        type="builtin",
                        name = bb,
                        def = bb,
                    }
                    if v.functext then theText = v.functext[1] end
                elseif bb:match("_") then                                    -- part of the capi
                    destItems = docRoots.capi.items
                    itemDef = {
                        type="c-api",
                        name = bb,
                        def = bb,
                    }
                    if v.functext then theText = v.functext[1] end
                elseif bb:match("[%.:]") then                                   -- builtin two part function
                    local myRoot, myLabel = bb:match("^([^%.:]+)[%.:]([^%.:]+)$")
                    if not docRoots[myRoot] then
                        docRoots[myRoot] = {
                            name  = functionPrefix.."."..myRoot,
                            desc  = myRoot,
                            doc   = "",
                            items = {},
                        }
                    end
                    destItems = docRoots[myRoot].items
                    itemDef = {
                        type="builtin",
                        name = myLabel,
                        def = bb,
                    }
                    if v.functext then theText = v.functext[1] end
                else                                                        -- builtin single part function
                    destItems = docRoots.builtin.items
                    itemDef = {
                        type="builtin",
                        name = bb,
                        def = bb,
                    }
                    if v.functext then theText = v.functext[1] end
                end
            end
            if v.mantext or v.functext then
                itemDef.doc = theText:gsub("([^\r\n~])[\r\n]([^%s\r\n~])","%1 %2")    -- join short lines
                                     :gsub("[\r\n][\r\n][\r\n]+","\n\n")              -- reduce bunches of newlines
                                     :gsub("^[\r\n]+",""):gsub("[\r\n]+$","")         -- string beginning and ending newlines
                table.insert(destItems, itemDef)
            else
                print("++ No text found for '"..bb.."', probably an error")
            end
        end
    end

-- check builtins to see if they match a subgroup, because we need to remove them from builtin...
    local removeBuiltinItems = {}
    for i,v in ipairs(docRoots.builtin.items) do
        if docRoots[v.name] then
            docRoots[v.name].doc = v.doc
            table.insert(removeBuiltinItems, i)
        end
    end
    for i = #removeBuiltinItems, 1, -1 do table.remove(docRoots.builtin.items, removeBuiltinItems[i]) end

-- flatten so it matches the expected doc format.
    local documentFormatArray -- comment out for debugging purposes
    documentFormatArray = {}
    for _,v in pairs(docRoots) do
        table.insert(documentFormatArray, v)
    end

-- Sort, because hs.doc is stupid about overwriting previously created subtables.
-- I know, I know... I ported/modified the %^$^%$& thing myself to make it work with Hammerspoon,
-- so I've no one to blame but, well, myself... I'll get around to it.
    table.sort(documentFormatArray, function(m,n)
        return m.name < n.name
    end)

    local f = io.open(destinationDocFile,"w")
        f:write(json.encode(documentFormatArray))
        f:close()
    print("++ Lua manual saved as "..destinationDocFile)
end):start()
