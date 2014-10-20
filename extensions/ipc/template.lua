--- === {PATH}.ipc ===
---
--- Provides a Message Port instance for inter-process-communication.  This is used to interface with {TARGET} from the command line.
---
--- To install the command line tool, you also need to install `{PATH}.ipc.cli`.
---
--- This module is based primarily on code from Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

--- {PATH}.ipc.cli
--- Command
--- This documents the external shell command `{CLI_NAME}` provided by the {PATH}.ipc module for external access to and control of your `{TARGET}` environment.
---
--- See the `{PATH}.ipc.cli_*` functions for information on how to install this tool so you can access it from your terminal.
---
--- The man page of the command line tool is provided here:
---
---     NAME
---          {CLI_NAME} -- Command line interface to {TARGET}.app
---
---     SYNOPSIS
---          {CLI_NAME} [-i | -s | -c code] [-r] [-n]
---
---     DESCRIPTION
---          Runs code from within {TARGET}, and prints the results. The given code is passed to "{PATH}.ipc.
---          handler" which normally executes it as plain Lua code, but may be overridden to do some custom
---          evaluation.
---
---          When no args are given, -i is implied.
---
---          -i       Runs in interactive-mode; uses each line as code . Prints in color unless otherwise speci-
---                   fied.
---          -c       Uses the given argument as code
---          -s       Uses stdin as code
---          -r       Forces {TARGET} to interpret code as raw Lua code; the function "{PATH}.ipc.handler" is not
---                   called.
---          -n       When specified, interactive-mode does not use colors.
---
---     EXIT STATUS
---          The {CLI_NAME} utility exits 0 on success, and >0 if an error occurs.
---
--- This module is based primarily on code from Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
---

local module_name = "{PATH}.ipc"
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

local internal = require("{PATH}.ipc.internal-ipc")

-- Public interface ------------------------------------------------------

--- {PATH}.ipc.handler(str) -> value
--- Function
--- The default handler for IPC, called by `{CLI_NAME}` from the command line. Default implementation evals the string and returns the result. You may override this function if for some reason you want to implement special evaluation rules for executing remote commands. The return value of this function is always turned into a string via tostring() and returned to `{CLI_NAME}` from the command line. If an error occurs, the error message is returned instead.
---
--- As an example, the default handler looks like this:
--- ~~~
---     function {PATH}.ipc.handler(str)
---         local fn, err = load("return " .. str)
---         if not fn then fn, err = load(str) end
---         if fn then return fn() else return err end
---     end
--- ~~~
{PATH}.ipc.handler = rawhandler


--- {PATH}.ipc.cli_get_colors() -> table
--- Function
---Returns a table containing three keys, `initial`, `input`, and `output`, which contain the terminal escape codes to generate the colors used in the command line interface.
{PATH}.ipc.cli_get_colors = function()
	local settings = require("{PATH}.settings")
	local colors = {}
	colors.initial = settings.get("ipc.cli.color_initial") or "\27[35m" ;
	colors.input = settings.get("ipc.cli.color_input") or "\27[33m" ;
	colors.output = settings.get("ipc.cli.color_output") or "\27[36m" ;
	return colors
end

--- {PATH}.ipc.cli_set_colors(table) -> table
--- Function
--- Takes as input a table containing one or more of the keys `initial`, `input`, or `output` to set the terminal escape codes to generate the colors used in the command line interface.  Each can be set to the empty string if you prefer to use the terminal window default.  Returns a table containing the changed color codes.
---
--- For a brief intro into terminal colors, you can visit a web site like this one (http://jafrog.com/2013/11/23/colors-in-terminal.html) (I have no affiliation with this site, it just seemed to be a clear one when I looked for an example... you can use Google to find many, many others).  Note that Lua doesn't support octal escapes in it's strings, so use `\x1b` or `\27` to indicate the `escape` character.
---
---    e.g. ipc.cli_set_colors{ initial = "", input = "\27[33m", output = "\27[38;5;11m" }
{PATH}.ipc.cli_set_colors = function(colors)
	local settings = require("{PATH}.settings")
	if colors.initial then settings.set("ipc.cli.color_initial",colors.initial) end
	if colors.input then settings.set("ipc.cli.color_input",colors.input) end
	if colors.output then settings.set("ipc.cli.color_output",colors.output) end
	return {PATH}.ipc.cli_get_colors()
end

--- {PATH}.ipc.cli_reset_colors()
--- Function
--- Erases any color changes you have made and resets the terminal to the original defaults.
{PATH}.ipc.cli_reset_colors = function()
	local settings = require("{PATH}.settings")
	settings.clear("ipc.cli.color_initial")
	settings.clear("ipc.cli.color_input")
	settings.clear("ipc.cli.color_output")
end

--- {PATH}.ipc.cli_is_installed([path]) -> bool
--- Function
--- Returns true or false indicating whether or not the command line tool, `{CLI_NAME}`, is installed or not.  Assumes a path of `/usr/local` for the test, unless path is specified. If a partial installation is detected, for example, the binary but not the man page, then an error will be printed to the console.
{PATH}.ipc.cli_is_installed = function(path)
    local path = path or "/usr/local"
    local bin_found = os.execute("[ -f "..path.."/bin/{CLI_NAME} ]")
    local man_found = os.execute("[ -f "..path.."/share/man/man1/{CLI_NAME}.1 ]")
    if not bin_found and os.execute("[ -L "..path.."/bin/{CLI_NAME} ]") then
        print([[cli installation problem: '{CLI_NAME}' is a dangling link. Remove with {PATH}.ipc.cli_uninstall("]]..path..[[", true).]])
    end
    if not bin_found and os.execute("[ -L "..path.."/bin/{CLI_NAME} ]") then
        print([[cli installation problem: man page for '{CLI_NAME}' is a dangling link. Remove with {PATH}.ipc.cli_uninstall("]]..path..[[", true).]])
    end
    if man_found ~= bin_found then
        if man_found then
            print("cli installation problem: man pages found, but '{CLI_NAME}' wasn't")
        else
            print("cli installation problem: '{CLI_NAME}' found, but man page wasn't")
        end
    end
    return bin_found or false
end

--- {PATH}.ipc.cli_is_available() -> bool
--- Function
--- Returns true or false indicating whether or not the command line tool and man page were packaged with the module or not.  The should only be false if `{PATH}.ipc` was installed manually and the command line tool was explicitly supressed.
{PATH}.ipc.cli_is_available = function()
    local mod_path = string.match(package.searchpath("hs.ipc",package.path), "^(.*)/init%.lua$")
    local bin_found = os.execute("[ -f "..mod_path.."/bin/{CLI_NAME} ]")
    local man_found = os.execute("[ -f "..mod_path.."/share/man/man1/{CLI_NAME}.1 ]")
    return bin_found and man_found or false
end

--- {PATH}.ipc.cli_install([path]) -> bool
--- Function
--- Creates symlinks for the command line tool and man page in the path specified (or /usr/local), so that {TARGET} can be accessed from the command line. Returns true or false indicating whether or not the tool has been successfully linked.
{PATH}.ipc.cli_install = function(path)
    local path = path or "/usr/local"
    local mod_path = string.match(package.searchpath("hs.ipc",package.path), "^(.*)/init%.lua$")
    if {PATH}.ipc.cli_is_available() then
        os.execute("ln -s "..mod_path.."/bin/{CLI_NAME} "..path.."/bin/")
        os.execute("ln -s "..mod_path.."/share/man/man1/{CLI_NAME}.1 "..path.."/share/man/man1/")
    end
    return {PATH}.ipc.cli_is_installed(path)
end

--- {PATH}.ipc.cli_uninstall([path[, force]]) ->
--- Function
--- Removes the symlinks for the command line tool and man page in the path specified (or /usr/local). {TARGET} wil no longer be accessible from the command line. Returns true or false indicating whether the tool has been successfully removed form the specified path. If you provide a path and a second variable that is true, then remove will attempt to remove the files, even if it doesn't think they are installed.  This can remove dangling link problems.
{PATH}.ipc.cli_uninstall = function(path, force)
    local path = path or "/usr/local"
    local force = (type(force) == "boolean") and force or false
    if force or {PATH}.ipc.cli_is_installed(path) then
        os.execute("rm "..path.."/bin/{CLI_NAME}")
        os.execute("rm "..path.."/share/man/man1/{CLI_NAME}.1")
    else
        return false
    end
    return not {PATH}.ipc.cli_is_installed(path)
end

-- Set-up metatable ------------------------------------------------------

internal.__messagePort = internal.__setup_ipc()
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

    local fn = raw and rawhandler or {PATH}.ipc.handler
    local results = table.pack(pcall(function() return fn(str) end))

    local str = fakestdout .. tostring(results[2])
    for i = 3, results.n do
        str = str .. "\t" .. tostring(results[i])
    end

    print = originalprint
    return str
end

setmetatable({PATH}.ipc, {
    __index = function(_, key) return internal[key] end,
    __gc = function(...)
        if internal.__messagePort then
            internal.__invalidate_ipc(internal.__messagePort)
        end
    end
})

-- Return Module Object --------------------------------------------------

return {PATH}.ipc

