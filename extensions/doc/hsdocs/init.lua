
--- === hs.doc.hsdocs ===
---
--- Manage the internal documentation web server.
---
--- This module provides functions for managing the Hammerspoon built-in documentation web server.  Currently, this is the same documentation available in the Dash docset for Hammerspoon, but does not require third party software for viewing.
---
--- Future enhancements to this module under consideration include:
---  * Support for third-party modules to add to the documentation set at run-time
---  * Markdown/HTML based tutorials and How-To examples
---  * Documentation for the LuaSkin Objective-C Framework
---  * Lua Reference documentation
---
--- The intent of this sub-module is to provide as close a rendering of the same documentation available at the Hammerspoon Github site and Dash documentation as possible in a manner suitable for run-time modification so module developers can test out documentation additions without requiring a complete recompilation of the Hammerspoon source.  As always, the most current and official documentation can be found at https://www.hammerspoon.org and in the official Hammerspoon Dash docset.

local module  = {}
-- private variables and methods -----------------------------------------

local USERDATA_TAG = "hs.doc.hsdocs"

local settings  = require"hs.settings"
local image     = require"hs.image"
local webview   = require"hs.webview"
local doc       = require"hs.doc"
local watchable = require"hs.watchable"
local timer     = require"hs.timer"
local host      = require"hs.host"
local hotkey    = require"hs.hotkey"

local documentRoot = package.searchpath("hs.doc.hsdocs", package.path):match("^(/.*/).*%.lua$")

local osVersion = host.operatingSystemVersion()

local toolbarImages = {
    prevArrow = image.imageFromASCII(".......\n" ..
                                     "..3....\n" ..
                                     ".......\n" ..
                                     "41....1\n" ..
                                     ".......\n" ..
                                     "..5....\n" ..
                                     ".......",
    {
        { strokeColor = { white = .5 } },
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = false },
        {},
    }),
    nextArrow = image.imageFromASCII(".......\n" ..
                                     "....3..\n" ..
                                     ".......\n" ..
                                     "1....14\n" ..
                                     ".......\n" ..
                                     "....5..\n" ..
                                     ".......",
    {
        { strokeColor = { white = .5 } },
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = false },
        {}
    }),
    lightMode = image.imageFromASCII("1.........2\n" ..
                                     "...........\n" ..
                                     "...........\n" ..
                                     ".....b.....\n" ..
                                     "...........\n" ..
                                     "...........\n" ..
                                     "....e.f....\n" ..
                                     "...........\n" ..
                                     "...a...c...\n" ..
                                     "...........\n" ..
                                     "4.........3",
    {
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 } },
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = false },
        { strokeColor = { white = .5 } },
        {}
    }),
    darkMode = image.imageFromASCII("1.........2\n" ..
                                    "...........\n" ..
                                    "...........\n" ..
                                    ".....b.....\n" ..
                                    "...........\n" ..
                                    "...........\n" ..
                                    "....e.f....\n" ..
                                    "...........\n" ..
                                    "...a...c...\n" ..
                                    "...........\n" ..
                                    "4.........3",
    {
        { strokeColor = { white = .75 }, fillColor = { alpha = 0.5 } },
        { strokeColor = { white = .75 }, fillColor = { alpha = 0.0 }, shouldClose = false },
        { strokeColor = { white = .75 } },
        {}
    }),
    followMode = image.imageFromASCII("2.........3\n" ..
                                      "...........\n" ..
                                      ".....g.....\n" ..
                                      "...........\n" ..
                                      "1...f.h...4\n" ..
                                      "6...b.c...9\n" ..
                                      "...........\n" ..
                                      "...a...d...\n" ..
                                      "...........\n" ..
                                      "7.........8",
    {
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = false },
        { strokeColor = { white = .75 }, fillColor = { alpha = 0.5 }, shouldClose = false },
        { strokeColor = { white = .75 }, fillColor = { alpha = 0.0 }, shouldClose = false },
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = true },
        {}
    }),
    noTrackWindow = image.imageFromASCII("1.........2\n" ..
                                         "4.........3\n" ..
                                         "6.........7\n" ..
                                         "...........\n" ..
                                         "...........\n" ..
                                         "...........\n" ..
                                         "...........\n" ..
                                         "...........\n" ..
                                         "...........\n" ..
                                         "9.........8",
    {
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.25 }, shouldClose = false },
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }},
        {}
    }),
    trackWindow = image.imageFromASCII("1.......2..\n" ..
                                       "4.......3..\n" ..
                                       "6.......7.c\n" ..
                                       "...........\n" ..
                                       "...........\n" ..
                                       "...........\n" ..
                                       "...........\n" ..
                                       "9.......8..\n" ..
                                       "...........\n" ..
                                       "..a.......b",
    {
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.25 }, shouldClose = false },
        { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }},
        { strokeColor = { white = .6 }, fillColor = { alpha = 0.0 }, shouldClose = false},
        {}
    }),
    index = image.imageFromName("statusicon"),
    help = image.imageFromName(image.systemImageNames.RevealFreestandingTemplate),
}

local frameTracker = function(cmd, wv, opt)
    if cmd == "frameChange" and settings.get("_documentationServer.trackBrowserFrameChanges") then
        settings.set("_documentationServer.browserFrame", opt)
    elseif cmd == "focusChange" then
        if module._modalKeys then
            if opt then module._modalKeys:enter() else module._modalKeys:exit() end
        end
    elseif cmd == "close" then
        if module._modalKeys then module._modalKeys:exit() end
    end
end

local updateToolbarIcons = function(toolbar, browser)
    local historyList = browser:historyList()

    if historyList.current > 1 then
        toolbar:modifyItem{ id = "prev", enable = true }
    else
        toolbar:modifyItem{ id = "prev", enable = false }
    end

    if historyList.current < #historyList then
        toolbar:modifyItem{ id = "next", enable = true }
    else
        toolbar:modifyItem{ id = "next", enable = false }
    end

    local mode = module.browserDarkMode()
    if type(mode) == "nil" then
        toolbar:modifyItem{ id = "mode", image = toolbarImages.followMode }
    elseif type(mode) == "boolean" then
        toolbar:modifyItem{ id = "mode", image = mode and toolbarImages.darkMode or toolbarImages.lightMode }
    elseif type(mode) == "number" then
        toolbar:modifyItem{ id = "mode", image = (mode > 50) and toolbarImages.darkMode or toolbarImages.lightMode }
    end

    toolbar:modifyItem{ id = "track", image = module.trackBrowserFrame() and toolbarImages.trackWindow or toolbarImages.noTrackWindow }
end

local makeModuleListForMenu = function()
    local searchList = {}
    for i,v in ipairs(doc._jsonForModules) do
        table.insert(searchList, v.name)
    end
    for i,v in ipairs(doc._jsonForSpoons) do
        table.insert(searchList, "spoon." .. v.name)
    end
    table.sort(searchList, function(a, b) return a:lower() < b:lower() end)
    return searchList
end

local makeToolbar = function(browser)
    local toolbar = webview.toolbar.new("hsBrowserToolbar", {
        {
            id = "index",
            label = "Index",
            image = toolbarImages.index,
            tooltip = "Display documentation index",
        },
        {
            id = "navigation",
            label = "Navigation",
            groupMembers = { "prev", "next" },
        },
        {
            id = "prev",
            tooltip = "Display previously viewed page in history",
            image = toolbarImages.prevArrow,
            enable = false,
            allowedAlone = false,
        },
        {
            id = "next",
            tooltip = "Display next viewed page in history",
            image = toolbarImages.nextArrow,
            enable = false,
            allowedAlone = false,
        },
        {
            id = "search",
            tooltip = "Search for a Hammerspoon function or method by name",
            searchfield = true,
            searchWidth = 250,
            searchPredefinedSearches = makeModuleListForMenu(),
            searchPredefinedMenuTitle = false,
            searchReleaseFocusOnCallback = true,
            fn = function(t, w, i, text)
                if text ~= "" then w:url("http://localhost:" .. tostring(module._server:port()) .. "/module.lp/" .. text) end
            end,
        },
        { id = "NSToolbarFlexibleSpaceItem" },
        {
            id = "mode",
            tooltip = "Toggle display mode between System/Dark/Light",
            image = toolbarImages.followMode,
        },
        {
            id = "track",
            tooltip = "Toggle window frame tracking",
            image = toolbarImages.noTrackWindow,
        },
        { id = "NSToolbarSpaceItem" },
        {
            id = "help",
            tooltip = "Display Browser Help",
            image = toolbarImages.help,
            fn = function(t, w, i) w:evaluateJavaScript("toggleHelp()") end,
        }
    }):canCustomize(true)
      :displayMode("icon")
      :sizeMode("small")
      :autosaves(true)
      :setCallback(function(t, w, i)
          if     i == "prev"  then w:goBack()
          elseif i == "next"  then w:goForward()
          elseif i == "index" then w:url("http://localhost:" .. tostring(module._server:port()) .. "/")
          elseif i == "mode"  then
              local mode = module.browserDarkMode()
              if type(mode) == "nil" then
                  module.browserDarkMode(true)
              elseif type(mode) == "boolean" then
                  if mode then
                      module.browserDarkMode(false)
                  else
                      module.browserDarkMode(nil)
                  end
              elseif type(mode) == "number" then
                  if mode < 50 then
                      module.browserDarkMode(false)
                  else
                      module.browserDarkMode(true)
                  end
              else
                  -- shouldn't be possible, but...
                  module.browserDarkMode(nil)
              end
--              w:reload()
              local current = module.browserDarkMode()
              if type(current) == "nil" then current = (host.interfaceStyle() == "Dark") end
              w:evaluateJavaScript("setInvertLevel(" .. (current and "100" or "0") .. ")")
              module._browser:darkMode(current)
          elseif i == "track" then
              local track = module.trackBrowserFrame()
              if track then
                  module.browserFrame(nil)
              end
              module.trackBrowserFrame(not track)
          else
              hs.luaSkinLog.wf("%s browser callback received %s and has no handler", USERDATA_TAG, i)
          end
          updateToolbarIcons(t, w)
      end)

    updateToolbarIcons(toolbar, browser)
    return toolbar
end

local defineHotkeys = function()
    local hk = hotkey.modal.new()
    hk:bind({"cmd"},          "f", nil, function() module._browser:evaluateJavaScript("toggleFind()") end)
    hk:bind({"cmd"},          "l", nil, function()
        if module._browser:attachedToolbar() then
            module._browser:attachedToolbar():selectSearchField()
        end
    end)
    hk:bind({"cmd"},          "r", nil, function() module._browser:evaluateJavaScript("window.location.reload(true)") end)

    hk:bind({},          "escape", nil, function()
        module._browser:evaluateJavaScript([[ document.getElementById("helpStuff").style.display == "block" ]], function(ans1)
            if ans1 then module._browser:evaluateJavaScript("toggleHelp()") end
            module._browser:evaluateJavaScript([[ document.getElementById("searcher").style.display == "block" ]], function(ans2)
                if ans2 then module._browser:evaluateJavaScript("toggleFind()") end
                if not ans1 and not ans2 then
                    module._browser:hide()
                    hk:exit()
                end
            end)
        end)
    end)

    hk:bind({"cmd"},          "g", nil, function()
        module._browser:evaluateJavaScript([[ document.getElementById("searcher").style.display == "block" ]], function(ans)
            if ans then
                module._browser:evaluateJavaScript("searchForText(0)")
            end
        end)
    end)
    hk:bind({"cmd", "shift"}, "g", nil, function()
        module._browser:evaluateJavaScript([[ document.getElementById("searcher").style.display == "block" ]], function(ans)
            if ans then
                module._browser:evaluateJavaScript("searchForText(1)")
            end
        end)
    end)

-- because these would interfere with the search field, we let Javascript handle these, see search.lp
--    hk:bind({},          "return", nil, function() end)
--    hk:bind({"shift"},   "return", nil, function() end)

    return hk
end

local makeBrowser = function()
    local screen   = require"hs.screen"

    local mainScreenFrame = screen:primaryScreen():frame()
    local browserFrame = settings.get("_documentationServer.browserFrame")
    if not (browserFrame and browserFrame.x and browserFrame.y and browserFrame.h and browserFrame.w) then
        browserFrame = {
            x = mainScreenFrame.x + 10,
            y = mainScreenFrame.y + 32,
            h = mainScreenFrame.h - 42,
            w = 800
        }
    end

    local options = {
        developerExtrasEnabled = true,
    }

    if (osVersion["major"] == 10 and osVersion["minor"] > 10) then
        options.privateBrowsing = true
        options.applicationName = "Hammerspoon/" .. hs.processInfo.version
    end

-- not used anymore, but just in case, I'm leaving the skeleton here...
--    local ucc = webview.usercontent.new("hsdocs"):setCallback(function(obj)
----        if obj.body == "message" then
----        else
--            print("~~ hsdocs unexpected ucc callback: ", require("hs.inspect")(obj))
----        end
--    end)

--    local browser = webview.new(browserFrame, options, ucc):windowStyle(1+2+4+8)
    local browser = webview.new(browserFrame, options):windowStyle(1+2+4+8)
      :allowTextEntry(true)
      :allowGestures(true)
      :windowCallback(frameTracker)
      :navigationCallback(function(a, w, n, e)
          if e then
              hs.luaSkinLog.ef("%s browser navigation for %s error:%s", USERDATA_TAG, a, e.localizedDescription)
              return true
          end
          if a == "didFinishNavigation" then
              updateToolbarIcons(w:attachedToolbar(), w)
          end
      end)

    module._modalKeys = defineHotkeys()
    browser:attachedToolbar(makeToolbar(browser))
    return browser
end

-- Public interface ------------------------------------------------------

module._moduleListChanges = watchable.watch("hs.doc", "changeCount", function(w, p, k, o, n)
    if module._browser then
        module._browser:attachedToolbar():modifyItem{
            id = "search",
            searchPredefinedSearches = makeModuleListForMenu(),
        }
    end
end)

--- hs.doc.hsdocs.interface([interface]) -> currentValue
--- Function
--- Get or set the network interface that the Hammerspoon documentation web server will be served on
---
--- Parameters:
---  * interface - an optional string, or nil, specifying the network interface the Hammerspoon documentation web server will be served on.  An explicit nil specifies that the web server should listen on all active interfaces for the machine.  Defaults to "localhost".
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * See `hs.httpserver.setInterface` for a description of valid values that can be specified as the `interface` argument to this function.
---  * A change to the interface can only occur when the documentation server is not running. If the server is currently active when you call this function with an argument, the server will be temporarily stopped and then restarted after the interface has been changed.
---
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.interface" and will persist through a reload or restart of Hammerspoon.
module.interface = function(...)
    local args = table.pack(...)
    if args.n > 0 then
        local newValue, needRestart = args[1], false
        if newValue == nil or type(newValue) == "string" then
            if module._server then
                needRestart = true
                module.stop()
            end
            if newValue == nil then
                settings.set("_documentationServer.interface", true)
            else
                settings.set("_documentationServer.interface", newValue)
            end
            if needRestart then
                module.start()
            end
        else
            error("interface must be nil or a string", 2)
        end
    end
    local current = settings.get("_documentationServer.interface") or "localhost"
    if current == true then
        return nil -- since nil has no meaning to settings, we use this boolean value as a placeholder
    else
        return current
    end
end

--- hs.doc.hsdocs.port([value]) -> currentValue
--- Function
--- Get or set the Hammerspoon documentation server HTTP port.
---
--- Parameters:
---  * value - an optional number specifying the port for the Hammerspoon documentation web server
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * The default port number is 12345.
---
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.serverPort" and will persist through a reload or restart of Hammerspoon.
module.port = function(...)
    local args = table.pack(...)
    local value = args[1]
    if args.n == 1 and (type(value) == "number" or type(value) == "nil") then
        if module._server then
            module._server:port(value or 12345)
        end
        settings.set("_documentationServer.serverPort", value)
    end
    return settings.get("_documentationServer.serverPort") or 12345
end

--- hs.doc.hsdocs.start() -> `hs.doc.hsdocs`
--- Function
--- Start the Hammerspoon internal documentation web server.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the table representing the `hs.doc.hsdocs` module
---
--- Notes:
---  * This function is automatically called, if necessary, when [hs.doc.hsdocs.help](#help) is invoked.
---  * The documentation web server can be viewed from a web browser by visiting "http://localhost:port" where `port` is the port the server is running on, 12345 by default -- see [hs.doc.hsdocs.port](#port).
module.start = function()
    if module._server then
        error("documentation server already running")
    else
        module._server = require"hs.httpserver.hsminweb".new(documentRoot)
        module._server:port(module.port())
                     :name("Hammerspoon Documentation")
                     :bonjour(true)
                     :luaTemplateExtension("lp")
                     :interface(module.interface())
                     :directoryIndex{
                         "index.html", "index.lp",
                     }:start()

        module._server._logBadTranslations       = true
        module._server._logPageErrorTranslations = true
        module._server._allowRenderTranslations  = true
    end
    return module
end

--- hs.doc.hsdocs.stop() -> `hs.doc.hsdocs`
--- Function
--- Stop the Hammerspoon internal documentation web server.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the table representing the `hs.doc.hsdocs` module
module.stop = function()
    if not module._server then
        error("documentation server not running")
    else
        module._server:stop()
        module._server = nil
    end
    return module
end

--- hs.doc.hsdocs.help([identifier]) -> nil
--- Function
--- Display the documentation for the specified Hammerspoon function, or the Table of Contents for the Hammerspoon documentation in a built-in mini browser.
---
--- Parameters:
---  * an optional string specifying a Hammerspoon module, function, or method to display documentation for. If you leave out this parameter, the table of contents for the Hammerspoon built-in documentation is displayed instead.
---
--- Returns:
---  * None
module.help = function(target)
    if not module._server then module.start() end

    local targetURL = "http://localhost:" .. tostring(module._server:port()) .. "/"
    if type(target) == "string" then
        targetURL = targetURL .. "module.lp/" .. target
    elseif type(target) == "table" and target.__path then
        targetURL = targetURL .. "module.lp/" .. target.__path
    end

    if webview and not settings.get("_documentationServer.forceExternalBrowser") then
        module._browser = module._browser or makeBrowser()
        module._browser:url(targetURL):show()
    else
        local targetApp = settings.get("_documentationServer.forceExternalBrowser")
        local urlevent = require"hs.urlevent"
        if type(targetApp) == "boolean" then
            targetApp = urlevent.getDefaultHandler("http")
        end
        if not urlevent.openURLWithBundle(targetURL, targetApp) then
            hs.luaSkinLog.wf("%s.help - hs.urlevent.openURLWithBundle failed to launch for bundle ID %s", USERDATA_TAG, targetApp)
            os.execute("/usr/bin/open " .. targetURL)
        end
    end
end

--- hs.doc.hsdocs.browserFrame([frameTable]) -> currentValue
--- Function
--- Get or set the currently saved initial frame location for the documentation browser.
---
--- Parameters:
---  * frameTable - a frame table containing x, y, h, and w values specifying the browser's initial position when Hammerspoon starts.
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * If [hs.doc.hsdocs.trackBrowserFrame](#trackBrowserFrame) is false or nil (the default), then you can use this function to specify the initial position of the documentation browser.
---  * If [hs.doc.hsdocs.trackBrowserFrame](#trackBrowserFrame) is true, then this any value set with this function will be overwritten whenever the browser window is moved or resized.
---
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.browserFrame" and will persist through a reload or restart of Hammerspoon.
module.browserFrame = function(...)
    local args = table.pack(...)
    local value = args[1]
    if args.n == 1 and (type(value) == "table" or type(value) == "nil") then
        if value and value.x and value.y and value.h and value.w then
            settings.set("_documentationServer.browserFrame", value)
        end
    end
    return settings.get("_documentationServer.browserFrame")
end

--- hs.doc.hsdocs.trackBrowserFrame([value]) -> currentValue
--- Function
--- Get or set whether or not changes in the documentation browsers location and size persist through launches of Hammerspoon.
---
--- Parameters:
---  * value - an optional boolean specifying whether or not the browsers location should be saved across launches of Hammerspoon.
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.trackBrowserFrameChanges" and will persist through a reload or restart of Hammerspoon.
module.trackBrowserFrame = function(...)
    local args = table.pack(...)
    if args.n == 1 and (type(args[1]) == "boolean" or type(args[1]) == "nil") then
        settings.set("_documentationServer.trackBrowserFrameChanges", args[1])
    end
    return settings.get("_documentationServer.trackBrowserFrameChanges")
end

--- hs.doc.hsdocs.moduleEntitiesInSidebar([value]) -> currentValue
--- Function
--- Get or set whether or not a module's entity list is displayed as a column on the left of the rendered page.
---
--- Parameters:
---  * value - an optional boolean specifying whether or not a module's entity list is displayed inline in the documentation (false) or in a sidebar on the left (true).
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * This is experimental and is disabled by default. It was inspired by a Userscript written by krasnovpro.  The original can be found at https://openuserjs.org/scripts/krasnovpro/hammerspoon.org_Documentation/source.
---
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.entitiesInSidebar" and will persist through a reload or restart of Hammerspoon.
module.moduleEntitiesInSidebar = function(...)
    local args = table.pack(...)
    if args.n == 1 and (type(args[1]) == "boolean" or type(args[1]) == "nil") then
        settings.set("_documentationServer.entitiesInSidebar", args[1])
    end
    return settings.get("_documentationServer.entitiesInSidebar")
end

--- hs.doc.hsdocs.browserDarkMode([value]) -> currentValue
--- Function
--- Get or set whether or not the Hammerspoon browser renders output in Dark mode.
---
--- Parameters:
---  * value - an optional boolean, number, or nil specifying whether or not the documentation browser renders in Dark mode.
---    * if value is `true`, then the HTML output will always be inverted
---    * if value is `false`, then the HTML output will never be inverted
---    * if value is `nil`, then the output will be inverted only when the OS X theme is set to Dark mode
---    * if the value is a number between 0 and 100, the number specifies the inversion ratio, where 0 means no inversion, 100 means full inversion, and 50 is completely unreadable because the foreground and background are equally adjusted.
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * Inversion is applied through the use of CSS filtering, so while numeric values other than 0 (false) and 100 (true) are allowed, the result is generally not what is desired.
---
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.invertDocs" and will persist through a reload or restart of Hammerspoon.
module.browserDarkMode = function(...)
    local args = table.pack(...)
    local value = args[1]
    if args.n == 1 and ({ ["number"] = 1, ["boolean"] = 1, ["nil"] = 1 })[type(value)] then
        if type(value) == "number" then value = (value < 0 and 0) or (value > 100 and 100) or value end
        settings.set("_documentationServer.invertDocs", value)
    end
    return settings.get("_documentationServer.invertDocs")
end

--- hs.doc.hsdocs.forceExternalBrowser([value]) -> currentValue
--- Function
--- Get or set whether or not [hs.doc.hsdocs.help](#help) uses an external browser.
---
--- Parameters:
---  * value - an optional boolean or string, default false, specifying whether or not documentation requests will be displayed in an external browser or the internal one handled by `hs.webview`.
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * If this value is set to true, help requests invoked by [hs.doc.hsdocs.help](#help) will be invoked by your system's default handler for the `http` scheme.
---  * If this value is set to a string, the string specifies the bundle ID of an application which will be used to handle the url request for the documentation.  The string should match one of the items returned by `hs.urlevent.getAllHandlersForScheme("http")`.
---
---  * This behavior is triggered automatically, regardless of this setting, if you are running with a version of OS X prior to 10.10, since `hs.webview` requires OS X 10.10 or later.
---
---  * Changes made with this function are saved with `hs.settings` with the label "_documentationServer.forceExternalBrowser" and will persist through a reload or restart of Hammerspoon.
module.forceExternalBrowser = function(...)
    local args = table.pack(...)
    local value = args[1]
    if args.n == 1 and (type(value) == "string" or type(value) == "boolean" or type(value) == "nil") then
        if type(value) == "string" then
            local validBundleIDs = require"hs.urlevent".getAllHandlersForScheme("http")
            local found = false
            for i, v in ipairs(validBundleIDs) do
                if v == value then
                    found = true
                    break
                end
            end
            if not found then
               error([[the string must match one of those returned by hs.urlevent.getAllHandlersForScheme("http")]])
            end
        end
        settings.set("_documentationServer.forceExternalBrowser", args[1])
    end
    return settings.get("_documentationServer.forceExternalBrowser")
end

-- Return Module Object --------------------------------------------------

return module
