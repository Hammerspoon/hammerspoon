--- === hs.ipc ===
---
--- Provides the server portion of the Hammerspoon command line interface
--- Note that in order to use the command line tool, you will need to explicitly load `hs.ipc` in your init.lua. The simplest way to do that is `require("hs.ipc")`
---
--- This module is based primarily on code from Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

--- hs.ipc.cli
--- Command
--- This documents the external shell command `hs` provided by the hs.ipc module for external access to and control of your `Hammerspoon` environment.
---
--- See the `hs.ipc.cli_*` functions for information on how to install this tool so you can access it from your terminal.
---
--- The man page of the command line tool is provided here:
---
---     NAME
---          hs -- Command line interface to Hammerspoon.app
---
---     SYNOPSIS
---          hs [-i | -s | -c code] [-r] [-n]
---
---     DESCRIPTION
---          Runs code from within Hammerspoon, and prints the results. The given code is passed to "hs.ipc.
---          handler" which normally executes it as plain Lua code, but may be overridden to do some custom
---          evaluation.
---
---          When no args are given, -i is implied.
---
---          -i       Runs in interactive-mode; uses each line as code . Prints in color unless otherwise speci-
---                   fied.
---          -c       Uses the given argument as code
---          -s       Uses stdin as code
---          -r       Forces Hammerspoon to interpret code as raw Lua code; the function "hs.ipc.handler" is not
---                   called.
---          -n       When specified, interactive-mode does not use colors.
---
---     EXIT STATUS
---          The hs utility exits 0 on success, and >0 if an error occurs.
---
--- This module is based primarily on code from Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
---

local module_name = "hs.ipc"
local root = _G
for part, sep in string.gmatch(module_name, "([%w_]+)(%.?)") do
    if sep == "." then
        if not root[part] or type(root[part]) == "table" then
            root[part] = root[part] or {}
            root = root[part]
        else
            error("Unable to create "..module_name.." because "..part.." is not a table.")
        end
    else
        root[part] = {}
    end
end

-- private variables and methods -----------------------------------------

local function rawhandler(str)
  local fn, err = load("return " .. str)
  if not fn then fn, err = load(str) end
  if fn then return fn() else return err end
end

local internal = require("hs.ipc.internal-ipc")

-- Public interface ------------------------------------------------------

--- hs.ipc.handler(str) -> value
--- Function
--- The default handler for IPC, called by `hs` from the command line. Default implementation evals the string and returns the result. You may override this function if for some reason you want to implement special evaluation rules for executing remote commands. The return value of this function is always turned into a string via tostring() and returned to `hs` from the command line. If an error occurs, the error message is returned instead.
---
--- As an example, the default handler looks like this:
--- ~~~
---     function hs.ipc.handler(str)
---         local fn, err = load("return " .. str)
---         if not fn then fn, err = load(str) end
---         if fn then return fn() else return err end
---     end
--- ~~~
hs.ipc.handler = rawhandler


--- hs.ipc.cliGetColors() -> table
--- Function
---Returns a table containing three keys, `initial`, `input`, and `output`, which contain the terminal escape codes to generate the colors used in the command line interface.
hs.ipc.cliGetColors = function()
	local settings = require("hs.settings")
	local colors = {}
	colors.initial = settings.get("ipc.cli.color_initial") or "\27[35m" ;
	colors.input = settings.get("ipc.cli.color_input") or "\27[33m" ;
	colors.output = settings.get("ipc.cli.color_output") or "\27[36m" ;
	return colors
end

--- hs.ipc.cliSetColors(table) -> table
--- Function
--- Takes as input a table containing one or more of the keys `initial`, `input`, or `output` to set the terminal escape codes to generate the colors used in the command line interface.  Each can be set to the empty string if you prefer to use the terminal window default.  Returns a table containing the changed color codes.
---
--- For a brief intro into terminal colors, you can visit a web site like this one (http://jafrog.com/2013/11/23/colors-in-terminal.html) (I have no affiliation with this site, it just seemed to be a clear one when I looked for an example... you can use Google to find many, many others).  Note that Lua doesn't support octal escapes in it's strings, so use `\x1b` or `\27` to indicate the `escape` character.
---
---    e.g. ipc.cliSetColors{ initial = "", input = "\27[33m", output = "\27[38;5;11m" }
hs.ipc.cliSetColors = function(colors)
	local settings = require("hs.settings")
	if colors.initial then settings.set("ipc.cli.color_initial",colors.initial) end
	if colors.input then settings.set("ipc.cli.color_input",colors.input) end
	if colors.output then settings.set("ipc.cli.color_output",colors.output) end
	return hs.ipc.cliGetColors()
end

--- hs.ipc.cliResetColors()
--- Function
--- Erases any color changes you have made and resets the terminal to the original defaults.
hs.ipc.cliResetColors = function()
	local settings = require("hs.settings")
	settings.clear("ipc.cli.color_initial")
	settings.clear("ipc.cli.color_input")
	settings.clear("ipc.cli.color_output")
end

--- hs.ipc.cliStatus([path][,silent]) -> bool
--- Function
--- Returns true or false indicating whether or not the command line tool, `hs`, is installed properly or not.  Assumes a path of `/usr/local` for the test, unless path is specified. Displays any issues (dangling link, partial installation, etc.) in the console, unless silent is provided and it is true.
hs.ipc.cliStatus = function(path, silent)
    local path = path or "/usr/local"
    local mod_path = string.match(package.searchpath("hs.ipc",package.path), "^(.*)/init%.lua$")

    local silent = silent or false

    local bin_file = os.execute("[ -f "..path.."/bin/hs ]")
    local man_file = os.execute("[ -f "..path.."/share/man/man1/hs.1 ]")
    local bin_link = os.execute("[ -L "..path.."/bin/hs ]")
    local man_link = os.execute("[ -L "..path.."/share/man/man1/hs.1 ]")
    local bin_ours = os.execute("[ "..path.."/bin/hs -ef "..mod_path.."/bin/hs ]")
    local man_ours = os.execute("[ "..path.."/share/man/man1/hs.1 -ef "..mod_path.."/share/man/man1/hs.1 ]")

    local result = bin_file and man_file and bin_link and man_link and bin_ours and man_ours or false
    local broken = false

    if not bin_ours and bin_file then
        if not silent then
            print([[cli installation problem: 'hs' is not ours.]])
        end
        broken = true
    end
    if not man_ours and man_file then
        if not silent then
            print([[cli installation problem: 'hs.1' is not ours.]])
        end
        broken = true
    end
    if bin_file and not bin_link then
        if not silent then
            print([[cli installation problem: 'hs' is an independant file won't be updated when Hammerspoon is.]])
        end
        broken = true
    end
    if not bin_file and bin_link then
        if not silent then
            print([[cli installation problem: 'hs' is a dangling link.]])
        end
        broken = true
    end
    if man_file and not man_link then
        if not silent then
            print([[cli installation problem: man page for 'hs.1' is an independant file and won't be updated when Hammerspoon is.]])
        end
        broken = true
    end
    if not man_file and man_link then
        if not silent then
            print([[cli installation problem: man page for 'hs.1' is a dangling link.]])
        end
        broken = true
    end
    if ((bin_file and bin_link) and not (man_file and man_link)) or ((man_file and man_link) and not (bin_file and bin_link)) then
        if not silent then
            print([[cli installation problem: incomplete installation of 'hs' and 'hs.1'.]])
        end
        broken = true
    end

    return broken and "broken" or result
end

--- hs.ipc.cliInstall([path][,silent]) -> bool
--- Function
--- Creates symlinks for the command line tool and man page in the path specified (or /usr/local), so that Hammerspoon can be accessed from the command line. Returns true or false indicating whether or not the tool has been successfully linked.  If silent is true, any issues are suppressed from the console.
hs.ipc.cliInstall = function(path, silent)
    local path = path or "/usr/local"
    local silent = silent or false
    if hs.ipc.cliStatus(path, true) == false then
        local mod_path = string.match(package.searchpath("hs.ipc",package.path), "^(.*)/init%.lua$")
        os.execute("ln -s "..mod_path.."/bin/hs "..path.."/bin/")
        os.execute("ln -s "..mod_path.."/share/man/man1/hs.1 "..path.."/share/man/man1/")
    end
    return hs.ipc.cliStatus(path, silent)
end

--- hs.ipc.cliUninstall([path][,silent]) -> bool
--- Function
--- Removes the symlinks for the command line tool and man page in the path specified (or /usr/local). Hammerspoon wil no longer be accessible from the command line. Returns true or false indicating whether the tool has been successfully removed form the specified path. If it appears that the files in question might not be ours, then this function does not remove the files and you will have to do so yourself or choose another path.  This is done to ensure that we minimize the chance that we remove something that belongs to another application.  If silent is true, any issues are suppressed from the console.
hs.ipc.cliUninstall = function(path, silent)
    local path = path or "/usr/local"
    local silent = silent or false
    if hs.ipc.cliStatus(path, silent) == true then
        os.execute("rm "..path.."/bin/hs")
        os.execute("rm "..path.."/share/man/man1/hs.1")
    else
        return false
    end
    return not hs.ipc.cliStatus(path, silent)
end

-- Set-up metatable ------------------------------------------------------

internal.__messagePort = internal.__setup_ipc()
if not internal.__messagePort then
    print("Warning: Unable to create IPC message port, you may already be running Hammerspoon.app")
    return nil
end

internal.__handler = function(raw, str)
    local originalprint = print
    local fakestdout = ""
    print = function(...)
        originalprint(...)
        local things = table.pack(...)
        for i = 1, things.n do
            if i > 1 then fakestdout = fakestdout .. "\t" end
            fakestdout = fakestdout .. tostring(things[i])
        end
        fakestdout = fakestdout .. "\n"
    end

    local fn = raw and rawhandler or hs.ipc.handler
    local results = table.pack(pcall(function() return fn(str) end))

    local str = ""
    for i = 2, results.n do
        if i > 2 then str = str .. "\t" end
        str = str .. tostring(results[i])
    end

    print = originalprint
    return fakestdout .. str
end

setmetatable(hs.ipc, {
    __index = function(_, key) return internal[key] end,
    __gc = function(...)
        if internal.__messagePort then
            internal.__invalidate_ipc(internal.__messagePort)
        end
    end
})

-- Return Module Object --------------------------------------------------

return hs.ipc

