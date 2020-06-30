--- === hs ===
---
--- Core Hammerspoon functionality

return {setup=function(...)
  local modpath, prettypath, fullpath, configdir, docstringspath, hasinitfile, autoload_extensions = ...
  local tostring,pack,tconcat,sformat,tsort=tostring,table.pack,table.concat,string.format,table.sort
  local traceback = debug.traceback
  local crashLog = require("hs.crash").crashLog
  local fnutils = require("hs.fnutils")
  local hsmath = require("hs.math")

  -- seed RNG before we do anything else
  math.randomseed(math.floor(hsmath.randomFloat()*100000000000000))

  -- setup core functions

  os.exit = hs._exit -- luacheck: ignore

--- hs.configdir
--- Constant
--- A string containing Hammerspoon's configuration directory. Typically `~/.hammerspoon/`
  hs.configdir = configdir

--- hs.dockIconClickCallback
--- Variable
--- An optional function that will be called when the Hammerspoon Dock Icon is clicked while the app is running
---
--- Notes:
---  * If set, this callback will be called regardless of whether or not Hammerspoon shows its console window in response to a click (which can be enabled/disabled via `hs.openConsoleOnDockClick()`
hs.dockIconClickCallback = nil

--- hs.shutdownCallback
--- Variable
--- An optional function that will be called when the Lua environment is being destroyed (either because Hammerspoon is exiting or reloading its config)
---
--- Notes:
---  * This function should not perform any asynchronous tasks
---  * You do not need to fastidiously destroy objects you have created, this callback exists purely for utility reasons (e.g. serialising state, destroying system resources that will not be released by normal Lua garbage collection processes, etc)
  hs.shutdownCallback = nil

--- hs.accessibilityStateCallback
--- Variable
--- An optional function that will be called when the Accessibility State is changed.
---
--- Notes:
---  * The function will not receive any arguments when called.  To check what the accessibility state has been changed to, you should call [hs.accessibilityState](#accessibilityState) from within your function.
hs.accessibilityStateCallback = nil

--- hs.textDroppedToDockIconCallback
--- Variable
--- An optional function that will be called when text is dragged to the Hammerspoon Dock Icon or sent via the Services menu
---
--- Notes:
---  * The function should accept a single parameter, which will be a string containing the text that was dragged to the dock icon
hs.textDroppedToDockIconCallback = nil

--- hs.fileDroppedToDockIconCallback
--- Variable
--- An optional function that will be called when a files are dragged to the Hammerspoon Dock Icon or sent via the Services menu
---
--- Notes:
---  * The function should accept a single parameter, which will be a string containing the full path to the file that was dragged to the dock icon
---  * If multiple files are sent, this callback will be called once for each file
---  * This callback will be triggered when ANY file type is dragged onto the Hammerspoon Dock Icon, however certain filetypes are also processed seperately by Hammerspoon. For example, `hs.urlevent` will be triggered when the following filetypes are dropped onto the Dock Icon: HTML Documents (.html, .htm, .shtml, .jhtml), Plain text documents (.txt, .text), Web site locations (.url), XHTML documents (.xhtml, .xht, .xhtm, .xht).
hs.fileDroppedToDockIconCallback = nil

--- hs.relaunch()
--- Function
--- Quits and relaunches Hammerspoon.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
hs.relaunch = function()
    os.execute([[ (while ps -p ]]..hs.processInfo.processID..[[ > /dev/null ; do sleep 1 ; done ; open -a "]]..hs.processInfo.bundlePath..[[" ) & ]])
    hs._exit(true, true)
end

--- hs.coroutineApplicationYield([delay])
--- Function
--- Yield coroutine to allow the Hammerspoon application to process other scheduled events and schedule a resume in the event application queue.
---
--- Parameters:
---  * `delay` - an optional number, default `hs.math.minFloat`, specifying the number of seconds from when this function is executed that the `coroutine.resume` should be scheduled for.
---
--- Returns:
---  * None
---
--- Notes:
---  * this function will return an error if invoked outside of a coroutine.
---  * unlike `coroutine.yield`, this function does not allow the passing of (new) information to or from the coroutine while it is running; this function is to allow long running tasks to yield time to the Hammerspoon application so other timers and scheduled events can occur without requiring the programmer to add code for an explicit resume.
---
---  * this function is added to the lua `coroutine` library as `coroutine.applicationYield` as an alternative name.
local resumeTimers = {}

hs.coroutineApplicationYield = function(delay)
    delay = delay or require"hs.math".minFloat

    local thread, isMain = coroutine.running()
    if not isMain then
        local uuid = require"hs.host".uuid()
        resumeTimers[uuid] = require"hs.timer".doAfter(delay, function()
            resumeTimers[uuid] = nil
            local status, msg = coroutine.resume(thread)
            if not status then
                hs.luaSkinLog.ef("hs.coroutineApplicationYield: %s", msg)
            end
        end)
        coroutine.yield()
    else
        error("attempt to yield from outside a coroutine", 2)
    end
end

coroutine.applicationYield = hs.coroutineApplicationYield

--- hs.docstrings_json_file
--- Constant
--- A string containing the full path to the `docs.json` file inside Hammerspoon's app bundle. This contains the full Hammerspoon API documentation and can be accessed in the Console using `help("someAPI")`. It can also be loaded and processed by the `hs.doc` extension
  hs.docstrings_json_file = docstringspath

--- hs.showError(err)
--- Function
--- Shows an error to the user, using Hammerspoon's Console
---
--- Parameters:
---  * err - A string containing an error message
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is called whenever an (uncaught) error occurs or is thrown (via `error()`)
---  * The default implementation shows a notification, opens the Console, and prints the error message and stacktrace
---  * You can override this function if you wish to route errors differently (e.g. for remote systems)

  function hs.showError(err)
    hs._notify("Hammerspoon error") -- undecided on this line
    --  print(traceback())
    print("*** ERROR: "..err)
    hs.focus()
    hs.openConsole()
  end

  function hs.assert(pred,desc,data)
    if not pred then error([[
  Internal error: please open an issue at
  https://github.com/Hammerspoon/hammerspoon/issues/new   and paste the following stack trace:

  Assertion failed: ]]..desc..'\n'..(data and hs.inspect(data) or ''),2)
    end
  end

--- hs.toggleConsole()
--- Function
--- Toggles the visibility of the console
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * If the console is not currently open, it will be opened. If it is open and not the focused window, it will be brought forward and focused.
---  * If the console is focused, it will be closed.
  function hs.toggleConsole()
    local console = hs.appfinder.windowFromWindowTitle("Hammerspoon Console")
    if console and (console ~= hs.window.focusedWindow()) then
      console:focus()
    elseif console then
      console:close()
    else
      hs.openConsole()
    end
  end

--- hs.rawprint(aString)
--- Function
--- The original Lua print() function
---
--- Parameters:
---  * aString - A string to be printed
---
--- Returns:
---  * None
---
--- Notes:
---  * Hammerspoon overrides Lua's print() function, but this is a reference we retain to is, should you need it for any reason
  local rawprint,logmessage = print,hs._logmessage
  hs.rawprint = rawprint
  function print(...) -- luacheck: ignore
--    rawprint(...)
    local vals = pack(...)

    for k = 1, vals.n do
      vals[k] = tostring(vals[k])
    end

    local str = tconcat(vals, "\t") .. "\n"
    logmessage(str)
  end

--- hs.printf(format, ...)
--- Function
--- Prints formatted strings to the Console
---
--- Parameters:
---  * format - A format string
---  * ... - Zero or more arguments to fill the placeholders in the format string
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a simple wrapper around the Lua code `print(string.format(...))`.
  function hs.printf(fmt,...) return print(sformat(fmt,...)) end


--- hs.execute(command[, with_user_env]) -> output, status, type, rc
--- Function
--- Runs a shell command, optionally loading the users shell environment first, and returns stdout as a string, followed by the same result codes as `os.execute` would return.
---
--- Parameters:
---  * command - a string containing the shell command to execute
---  * with_user_env - optional boolean argument which if provided and is true, executes the command in the users login shell as an "interactive" login shell causing the user's local profile (or other login scripts) to be loaded first.
---
--- Returns:
---  * output -- the stdout of the command as a string.  May contain an extra terminating new-line (\n).
---  * status -- `true` if the command terminated successfully or nil otherwise.
---  * type   -- a string value of "exit" or "signal" indicating whether the command terminated of its own accord or if it was terminated by a signal (killed, segfault, etc.)
---  * rc     -- if the command exited of its own accord, then this number will represent the exit code (usually 0 for success, not 0 for an error, though this is very command specific, so check man pages when there is a question).  If the command was killed by a signal, then this number corresponds to the signal type that caused the command to terminate.
---
--- Notes:
---  * Setting `with_user_env` to true does incur noticeable overhead, so it should only be used if necessary (to set the path or other environment variables).
---  * Because this function returns the stdout as it's first return value, it is not quite a drop-in replacement for `os.execute`.  In most cases, it is probable that `stdout` will be the empty string when `status` is nil, but this is not guaranteed, so this trade off of shifting os.execute's results was deemed acceptable.
---  * This particular function is most useful when you're more interested in the command's output then a simple check for completion and result codes.  If you only require the result codes or verification of command completion, then `os.execute` will be slightly more efficient.
---  * If you need to execute commands that have spaces in their paths, use a form like: `hs.execute [["/Some/Path To/An/Executable" "--first-arg" "second-arg"]]`
  hs.execute = function(command, user_env)
    local f
    if user_env then
      f = io.popen(os.getenv("SHELL")..[[ -l -i -c "]]..command..[["]], 'r')
    else
      f = io.popen(command, 'r')
    end
    local s = f:read('*a')
    local status, exit_type, rc = f:close()
    return s, status, exit_type, rc
  end

--- hs.dockIcon([state]) -> bool
--- Function
--- Set or display whether or not the Hammerspoon dock icon is visible.
---
--- Parameters:
---  * state - an optional boolean which will set whether or not the Hammerspoon dock icon should be visible.
---
--- Returns:
---  * True if the icon is currently set (or has just been) to be visible or False if it is not.
---
--- Notes:
---  * This function is a wrapper to functions found in the `hs.dockicon` module, but is provided here to provide an interface consistent with other selectable preference items.
  hs.dockIcon = function(value)
    local hsdi = require("hs.dockicon")
    if type(value) == "boolean" then
      if value then hsdi.show() else hsdi.hide() end
    end
    return hsdi.visible()
  end

--- hs.loadSpoon(name[, global]) -> Spoon object
--- Function
--- Loads a Spoon
---
--- Parameters:
---  * name - The name of a Spoon (without the trailing `.spoon`)
---  * global - An optional boolean. If true, this function will insert the spoon into Lua's global namespace as `spoon.NAME`. Defaults to true.
---
--- Returns:
---  * The object provided by the Spoon (which can be ignored if you chose to make the Spoon global)
---
--- Notes:
---  * Spoons are a way of distributing self-contained units of Lua functionality, for Hammerspoon. For more information, see https://github.com/Hammerspoon/hammerspoon/blob/master/SPOON.md
---  * This function will load the Spoon and call its `:init()` method if it has one. If you do not wish this to happen, or wish to use a Spoon that somehow doesn't fit with the behaviours of this function, you can also simply `require('name')` to load the Spoon
---  * If the Spoon provides documentation, it will be loaded by made available in hs.docs
---  * To learn how to distribute your own code as a Spoon, see https://github.com/Hammerspoon/hammerspoon/blob/master/SPOON.md
  hs.loadSpoon = function (name, global)
    print("-- Loading Spoon: "..name)

    -- First, find the full path of the Spoon
    local spoonFile = package.searchpath(name, package.path)
    if spoonFile == nil then
        hs.showError("Unable to load Spoon: "..name)
        return
    end
    local spoonPath = spoonFile:match("(.*/)")

    -- Check if the Spoon contains a meta.json
    local metaData = {}
    local mf = io.open(spoonPath.."meta.json", "r")
    if mf then
        local fileData = mf:read("*a")
        mf:close()
        local json = require("hs.json")
        local metaDataTmp = json.decode(fileData)
        if metaDataTmp then
            metaData = metaDataTmp
        end
    end

    -- Load the Spoon code
    local obj = require(name)

    if obj then
      -- Inject the full path of the Spoon
      obj.spoonPath = spoonPath
      -- Inject the Spoon's metadata
      obj.spoonMeta = metaData

      -- If the Spoon has an init method, call it
      if obj.init then
        obj:init()
      end

      -- If the Spoon is desired to be global, make it so
      if global ~= false then
        if _G["spoon"] == nil then
          _G["spoon"] = {}
        end
        _G["spoon"][name] = obj
      end

      -- If the Spoon has docs, load them
      if obj.spoonPath then
        local docsPath = obj.spoonPath.."/docs.json"
        local fs = require("hs.fs")
        if fs.attributes(docsPath) then
          local doc = require("hs.doc")
          doc.registerJSONFile(docsPath, true)
        end
      end
    end

    -- Return the Spoon object
    return obj
  end

--- hs.help(identifier)
--- Function
--- Prints the documentation for some part of Hammerspoon's API and Lua 5.3.  This function is actually sourced from hs.doc.help.
---
--- Parameters:
---  * identifier - A string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`)
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is mainly for runtime API help while using Hammerspoon's Console
---  * You can also access the results of this function by the following methods from the console:
---    * help("identifier") -- quotes are required, e.g. `help("hs.reload")`
---    * help.identifier.path -- no quotes are required, e.g. `help.hs.reload`
---  * Lua information can be accessed by using the `lua` prefix, rather than `hs`.
---    * the identifier `lua._man` provides the table of contents for the Lua 5.3 manual.  You can pull up a specific section of the lua manual by including the chapter (and subsection) like this: `lua._man._3_4_8`.
---    * the identifier `lua._C` will provide information specifically about the Lua C API for use when developing modules which require external libraries.

  hs.help = require("hs.doc")
  help = hs.help -- luacheck: ignore


--- hs.hsdocs([identifier])
--- Function
--- Display's Hammerspoon API documentation in a webview browser.
---
--- Parameters:
---  * identifier - An optional string containing the signature of some part of Hammerspoon's API (e.g. `"hs.reload"`).  If no string is provided, then the table of contents for the Hammerspoon documentation is displayed.
---
--- Returns:
---  * None
---
--- Notes:
---  * You can also access the results of this function by the following methods from the console:
---    * hs.hsdocs.identifier.path -- no quotes are required, e.g. `hs.hsdocs.hs.reload`
---  * See `hs.doc.hsdocs` for more information about the available settings for the documentation browser.
---  * This function provides documentation for Hammerspoon modules, functions, and methods similar to the Hammerspoon Dash docset, but does not require any additional software.
---  * This currently only provides documentation for the built in Hammerspoon modules, functions, and methods.  The Lua documentation and third-party modules are not presently supported, but may be added in a future release.
  local hsdocsMetatable
  hsdocsMetatable = {
    __index = function(self, key)
      local label = (self.__node == "") and key or (self.__node .. "." .. key)
      return setmetatable({ __action = self.__action, __node = label }, hsdocsMetatable)
    end,

    __call = function(self, ...)
      if type(self.__action) == "function" then
          return self.__action(self.__node, ...)
      else
          return self.__node
      end
    end,

    __tostring = function(self) self.__action(self.__node) ; return self.__node end
  }

  hs.hsdocs = setmetatable({
    __node = "",
    __action = function(what)
        local hsdocs = require("hs.doc.hsdocs")
        hsdocs.help((what ~= "") and what or nil)
    end
  }, hsdocsMetatable)

  --setup lazy loading
  if autoload_extensions then
    print("-- Lazy extension loading enabled")
    hs._extensions = {}

    -- Discover extensions in our .app bundle
    local fs = require("hs.fs")
    local iter, dir_obj = fs.dir(modpath.."/hs")
    local extension = iter(dir_obj)
    while extension do
      if (extension ~= ".") and (extension ~= "..") then
        hs._extensions[extension] = true
      end
      extension = iter(dir_obj)
    end

    -- Inject a lazy extension loader into the main HS table
    setmetatable(hs, {
      __index = function(_, key)
        if hs._extensions[key] ~= nil then
          print("-- Loading extension: "..key)
          hs[key] = require("hs."..key)
          return hs[key]
        else
          return nil
        end
      end
    })
  end

  local logger = require("hs.logger").new("LuaSkin", "info")
  hs.luaSkinLog = logger

  hs.handleLogMessage = function(level, message)
      local levelLabels = { "ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE" }
    -- may change in the future if this fills crashlog with too much useless stuff
      if level ~= 5 then
          crashLog(sformat("(%s) %s", (levelLabels[level] or tostring(level)), message))
      end

      if level == 5 then     logger.v(message) -- LS_LOG_VERBOSE
      elseif level == 4 then logger.d(message) -- LS_LOG_DEBUG
      elseif level == 3 then logger.i(message) -- LS_LOG_INFO
      elseif level == 2 then logger.w(message) -- LS_LOG_WARN
      elseif level == 1 then logger.e(message) -- LS_LOG_ERROR
--           hs.showError(message)
      else
          print("*** UNKNOWN LOG LEVEL: "..tostring(level).."\n\t"..message)
      end
  end

  hs.__appleScriptRunString = function(s)

    --print("runstring")
    local fn, err = load("return " .. s)
    if not fn then fn, err = load(s) end
    if not fn then return false, tostring(err) end

    local str = ""
    local results = pack(xpcall(fn,traceback))
    for i = 2,results.n do
      if i > 2 then str = str .. "\t" end
      str = str .. tostring(results[i])
    end
    return results[1], str
  end

  -- load init.lua

  local function runstring(s)
    if hs._consoleInputPreparser then
      if type(hs._consoleInputPreparser) == "function" then
        local status, s2 = pcall(hs._consoleInputPreparser, s)
        if status then
          s = s2
        else
          hs.luaSkinLog.ef("console preparse error: %s", s2)
        end
      else
          hs.luaSkinLog.e("console preparser must be a function or nil")
      end
    end

    --print("runstring")
    local fn, err = load("return " .. s)
    if not fn then fn, err = load(s) end
    if not fn then return tostring(err) end

    local str = ""
    local results = pack(xpcall(fn,traceback))
    for i = 2,results.n do
      if i > 2 then str = str .. "\t" end
      str = str .. tostring(results[i])
    end
    return str
  end

  local function tableSet(t)
    local hash = {}
    local res = {}
    for _, v in ipairs(t) do
      if not hash[v] then
        res[#res+1] = v
        hash[v] = true
      end
    end
    return res
  end

  local function tablesMerge(t1, t2)
    for i = 1, #t2 do
      t1[#t1 + 1] = t2[i]
    end
    return t1
  end

  local function tableKeys(t)
    local keyset={}
    local n=0
    for k,_ in pairs(t) do
      n=n+1
      keyset[n]=k
    end
    tsort(keyset)
    return keyset
  end

  local function typeWithSuffix(item, table)
    local suffix = ""
    if type(table[item]) == "function" then
      suffix = "("
    end
    return item..suffix
  end

  local function filterForRemnant(table, remnant)
    return fnutils.ifilter(table, function(item)
      return string.find(item, "^"..remnant)
    end)
  end

  local function findCompletions(table, remnant)
    if type(table) ~= "table" then return {} end
    return filterForRemnant(fnutils.imap(tableKeys(table), function(item)
      return typeWithSuffix(item, table)
    end), remnant)
  end

--- hs.completionsForInputString(completionWord) -> table of strings
--- Variable
--- Gathers tab completion options for the Console window
---
--- Parameters:
---  * completionWord - A string from the Console window's input field that completions are needed for
---
--- Returns:
---  * A table of strings, each of which will be shown as a possible completion option to the user
---
--- Notes:
---  * Hammerspoon provides a default implementation of this function, which can complete against the global Lua namespace, the 'hs' (i.e. extension) namespace, and object metatables. You can assign a new function to the variable to replace it with your own variant.
  function hs.completionsForInputString(completionWord)
    local completions = {}
    local mapJoiner = "."
    local mapEnder = ""

    completionWord = string.find(completionWord, "[%[%(]$") and " " or completionWord
    local mod = string.match(completionWord, "(.*)[%.:]") or ""
    local remnant = string.gsub(completionWord, mod, "")
    remnant = string.gsub(remnant, "[%.:](.*)", "%1")
    local parents = fnutils.split(mod, '%.')
    local src = _G

--print(sformat("completionWord: %s", completionWord))
--print(sformat("mod: %s", mod))
--print(sformat("remnant: %s", remnant))
--print(sformat("parents: %s", hs.inspect(parents)))

    if not mod or mod == "" then
      -- Easiest case first, we have no text to work with, so just return keys from _G
      mapJoiner = ""
      completions = findCompletions(src, remnant)
    elseif mod == "hs" then
      -- We're either at the top of the 'hs' namespace, or completing the first level under it
      -- NOTE: We can't use findCompletions() here because it will inspect the tables too deeply and cause the full set of modules to be loaded
      completions = filterForRemnant(tableSet(tablesMerge(tableKeys(hs), tableKeys(hs._extensions))), remnant)
    elseif mod and string.find(completionWord, ":") then
      -- We're trying to complete an object's methods
      mapJoiner = ":"
      src = src[mod]
      if type(src) == "userdata" then
        src = hs.getObjectMetatable(getmetatable(src).__name or "") or hs.getObjectMetatable(getmetatable(src).__type or "") or getmetatable(src).__index
      end
      completions = findCompletions(src, remnant)
    elseif mod and #parents > 0 then
      -- We're some way inside the hs. namespace, so walk our way down the ancestral chain to find the final table
      for i=1, #parents do
        src=src[parents[i]]
      end
      -- If nothing left to show, show nothing
      if src ~= nil then
        completions = findCompletions(src, remnant)
      end
    end

    return fnutils.map(completions, function(item) return mod..mapJoiner..item..mapEnder end)
  end

  if not hasinitfile then
    local notify = require("hs.notify")
    local printf = hs.printf
    notify.register("__noinitfile", function() os.execute("open http://www.hammerspoon.org/go/") end)
    notify.show("Hammerspoon", "No config file found", "Click here for the Getting Started Guide", "__noinitfile")
    printf("-- Can't find %s; create it and reload your config.", prettypath)
    return hs.completionsForInputString, runstring
  end

  local hscrash = require("hs.crash")

  -- These three modules are so tightly coupled that we will unconditionally preload them
  require("hs.application.internal")
  require("hs.uielement")
  require("hs.window")
  require("hs.application")

  rawrequire = require
  require = function(modulename) -- luacheck: ignore
    local result = rawrequire(modulename)
    pcall(function()
    hscrash.crashLog("require: "..modulename)
      --if string.sub(modulename, 1, 3) == "hs." then
      --  -- Reasonably certain that we're dealing with a Hammerspoon extension
      --  local extname = string.sub(modulename, 4, -1)
      --  for k,v in ipairs(hscrash.dumpCLIBS()) do
      --    if string.find(v, extname) then
      --      hscrash.crashLog("  Candidate CLIBS match: "..v)
      --    end
      --  end
      --end
      if string.sub(modulename, 1, 8) == "mjolnir." then
        -- Reasonably certain that we're dealing with a Mjolnir module
        local mjolnirmod = string.sub(modulename, 9, -1)
        local mjolnirrep = {"application", "hotkey", "screen", "geometry", "fnutils", "keycodes", "alert", "cmsj.appfinder", "_asm.ipc", "_asm.modal_hotkey", "_asm.settings", "7bits.mjomatic", "_asm.eventtap.event", "_asm.timer", "_asm.pathwatcher", "_asm.eventtap", "_asm.notify", "lb.itunes", "_asm.utf8_53", "cmsj.caffeinate", "lb.spotify", "_asm.sys.mouse", "_asm.sys.battery", "_asm.ui.sound", "_asm.data.base64", "_asm.data.json"}
        for _,v in pairs(mjolnirrep) do
          if v == mjolnirmod then
            hscrash.crashKV("MjolnirModuleLoaded", "YES")
            break
          end
        end
      end
    end)
    return result
  end

  -- Set up the default Console toolbar
--- hs.console.defaultToolbar
--- Constant
--- Default toolbar for the Console window
---
--- Notes:
---  * This is an `hs.toolbar` object that is shown by default in the Hammerspoon Console
---  * You can remove this toolbar by adding `hs.console.toolbar(nil)` to your config, or you can replace it with your own `hs.webview.toolbar` object
  local toolbar = require("hs.webview.toolbar")
  local console = require("hs.console")
  local image = require("hs.image")
  console.defaultToolbar = toolbar.new("Console Default", {
    { id="prefs", label="Preferences", image=image.imageFromName("NSPreferencesGeneral"), tooltip="Open Preferences", fn=function() hs.openPreferences() end },
    { id="reload", label="Reload config", image=image.imageFromName("NSSynchronize"), tooltip="Reload configuration", fn=function() hs.reload() end },
    { id="help", label="Help", image=image.imageFromName("NSInfo"), tooltip="Open API docs browser", fn=function() hs.doc.hsdocs.help() end }
  }):canCustomize(true):autosaves(true)
  console.toolbar(console.defaultToolbar)

  hscrash.crashLog("Loaded from: "..modpath)

  print("-- Loading " .. prettypath)
  local fn, err = loadfile(fullpath)
  if not fn then hs.showError(err) return hs.completionsForInputString, runstring end

  local ok, errorMessage = xpcall(fn, traceback)
  if not ok then hs.showError(errorMessage) return hs.completionsForInputString, runstring end

  print "-- Done."

  return hs.completionsForInputString, runstring
end}
