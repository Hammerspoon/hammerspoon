-- spoon doc support
--
-- [x] find spoons installed
-- [x] identify documentation json file for each
--   [x] if found, register for docs: -- registration happens in hs.doc's init.lua
--     [x] console help
--     [ ] hsdocs
--     [ ] exportable html/md ?   -- not in initial release
--     [ ] custom built docset ?  -- not in initial release
--   [x] if not found, generate json then register -- registration happens in hs.doc's init.lua

--- === hs.doc.spoonsupport ===
---
--- Provides run-time support for generating and including documentation for installed Hammerspoon Spoon bundles.
---
--- This module provides support for building (if necessary) and loading the documentation for installed Spoon bundles.  In general, it is not expected that most users will have a need to access these functions directly.

local module = {}
local settings = require "hs.settings"
local fs       = require "hs.fs"
local builder  = require "hs.doc.builder"

-- won't default to debug in release... debating between "error" and "none" as default and
-- using hs.settings to allow setting it based on user preference
local log = require("hs.logger").new("spoonDocs", settings.get("hs.doc.spoons.logLevel") or "warning")

local documentationFileName = "docs.json"


local findSpoons = function()
    local spoonPaths, installedSpoons = {}, {}
    for path in package.path:gmatch("([^;]+Spoons/%?%.spoon/init%.lua)") do
        table.insert(spoonPaths, path)
    end
    for _, v in ipairs(spoonPaths) do
        local dirPath = v:match("^(.+)/%?%.spoon/init%.lua$")
        if dirPath and fs.dir(dirPath) then
            for file in fs.dir(dirPath) do
                local name = file:match("^(.+)%.spoon$")
                local spoonInit = name and package.searchpath(name, table.concat(spoonPaths, ";"))
                if name and spoonInit then
                    local spoonDetails = {}
                    spoonDetails.path     = spoonInit:match("^(.+)/init%.lua$")
                    spoonDetails.docPath  = spoonDetails.path .. "/" .. documentationFileName
                    spoonDetails.hasDocs  = fs.attributes(spoonDetails.docPath) and true or false
                    installedSpoons[name] = spoonDetails
                else
                    if not file:match("^%.%.?$") then
                        log.df("skipping %s -- missing init.lua", file)
                    end
                end
            end
        end
    end
    return spoonPaths, installedSpoons
end

local makeDocsFile = function(path, overwrite)
    assert(type(path) == "string", "must specify a path")

    local destinationPath = path .. "/" .. documentationFileName
    if overwrite or not fs.attributes(destinationPath) then
        local stat, output = pcall(builder.genJSON, path)
        if stat then
            local f, e = io.open(destinationPath, "w+")
            if f then
                f:write(output)
                f:close()
            else
                log.ef("unable to open %s for writing:\n\t%s", destinationPath, e)
            end
        else
            log.ef("error generating documentation for %s:\n\t%s", path, output)
        end
    else
        log.wf("will not overwrite %s without being forced", destinationPath)
    end
end

local updateDocsFiles = function()
    local _, installedSpoons = findSpoons()
    for k, v in pairs(installedSpoons) do
        if not v.hasDocs then
            log.df("creating docs file for %s", k)
            makeDocsFile(v.path)
        else
            local initFile, docsFile = fs.attributes(v.path .. "/init.lua"), fs.attributes(v.docPath)
            if initFile.change > docsFile.change then
                log.df("updating docs file for %s", k)
                makeDocsFile(v.path, true)
            else
                log.vf("docs file for %s current", k)
            end
        end
    end
end

module.log = log

--- hs.doc.spoonsupport.findSpoons() -> pathTable, spoonsTable
--- Function
--- Returns tables describing where spoons are installed and what spoons are currently available.
---
--- Parameters:
---  * None
---
--- Returns:
---  * two tables:
---    * an array containing the paths from `package.path` which can contain Hammerspoon Spoon bundles.
---    * a table with key-value pairs where the key matches an installed (but not necessarily loaded) spoon name and the value is a table containing the following keys:
---      * path    - the path to the directory which contains the contents of the Spoon bundle
---      * docPath - the expected path for documentation for this Spoon bundle
---      * hasDocs - a boolean indicating whether or not the file referred to by `docPath` exists and is readable
module.findSpoons      = findSpoons

--- hs.doc.spoonsupport.updateDocFiles() -> none
--- Function
--- Creates and updates the included documentation for the installed Spoon bundles if the documentation file is not present or the init.lua file for the Spoon has been modified more recently then the documentation file.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * The Spoon documentation is expected to be in a file named `docs.json` at the root level of the Spoon bundle.
module.updateDocsFiles = updateDocsFiles

--- hs.doc.spoonsupport.makeDocsFile(spoonPath, [force]) -> none
--- Function
--- Create the docs.json file for the Spoon bundle at the specified path.
---
--- Parameters:
---  * spoonPath - the path of the Spoon bundle to generate the documentation for
---  * force     - an optional boolean, default false, indicating whether or not an existing `docs.json` file within the Spoon bundle should be overwritten.
---
--- Returns:
---  * None
module.makeDocsFile    = makeDocsFile

return module
