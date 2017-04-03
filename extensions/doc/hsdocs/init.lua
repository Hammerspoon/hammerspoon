
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
--- The intent of this sub-module is to provide as close a rendering of the same documentation available at the Hammerspoon Github site and Dash documentation as possible in a manner suitable for run-time modification so module developers can test out documentation additions without requiring a complete recompilation of the Hammerspoon source.  As always, the most current and official documentation can be found at http://www.hammerspoon.org and in the official Hammerspoon Dash docset.

local module  = {}
-- private variables and methods -----------------------------------------

local USERDATA_TAG = "hs.doc.hsdocs"

local settings = require"hs.settings"
local image    = require"hs.image"
local webview  = require"hs.webview"

local documentRoot = package.searchpath("hs.doc.hsdocs", package.path):match("^(/.*/).*%.lua$")

local osVersion = require"hs.host".operatingSystemVersion()

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
}

local makeWatcher = function(browser)
    if not module._browserWatcher and settings.get("_documentationServer.trackBrowserFrameChanges") then
        require"hs.timer".waitUntil(
            function() return module._browser:hswindow() ~= nil end,
            function(...)
                module._browserWatcher = browser:hswindow()
                                                :newWatcher(function(element, event, watcher, userData)
                                                    if event == "AXUIElementDestroyed" then
                                                        module._browserWatcher:stop()
                                                        module._browserWatcher = nil
                                                    else
                                                      -- ^%$#$@#&%^*$ hs.geometry means element:frame() isn't really a rect, and there is no direct function to coerce it...
                                                        local notFrame = element:frame()
                                                        local frame = {
                                                            x = notFrame._x,
                                                            y = notFrame._y,
                                                            h = notFrame._h,
                                                            w = notFrame._w,
                                                        }
                                                        settings.set("_documentationServer.browserFrame", frame)
                                                    end
                                                end, module._browser):start({
                                                    "AXWindowMoved",
                                                    "AXWindowResized",
                                                    "AXUIElementDestroyed"
                                                })
          end)
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

    if settings.get("_documentationServer.trackBrowserFrameChanges") then
        if not module._browserWatcher then
            makeWatcher(browser)
        end
    else
        if module._browserWatcher then
            module._browserWatcher:stop()
            module._browserWatcher = nil
        end
    end
end

local makeToolbar = function(browser)
    local examineDocumentation
    examineDocumentation = function(tblName)
        local myTable = {}
        for i, v in pairs(tblName) do
            if type(v) == "table" then
                if v.__name == v.__path then
                    table.insert(myTable, v.__name)
                    local more = examineDocumentation(v)
                    if #more > 0 then
                        for i2,v2 in ipairs(more) do table.insert(myTable, v2) end
                    end
                end
            end
        end
        return myTable
    end
    local searchList = examineDocumentation(hs.help.hs)
    table.insert(searchList, "hs")
    table.sort(searchList)

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
            tooltip = "Display previous page",
            image = toolbarImages.prevArrow,
            enable = false,
            allowedAlone = false,
        },
        {
            id = "next",
            tooltip = "Display next page",
            image = toolbarImages.nextArrow,
            enable = false,
            allowedAlone = false,
        },
        {
            id = "search",
            tooltip = "Search for a HS function or method",
            searchfield = true,
            searchWidth = 250,
            searchPredefinedSearches = searchList,
            searchPredefinedMenuTitle = false,
            fn = function(t, w, i, text)
                if text ~= "" then w:url("http://localhost:" .. tostring(module._server:port()) .. "/module.lp/" .. text) end
            end,
        },
        { id = "NSToolbarFlexibleSpaceItem" },
        {
            id = "mode",
            tooltip = "Toggle display mode",
            image = toolbarImages.followMode,
        },
        {
            id = "track",
            tooltip = "Toggle window frame tracking",
            image = toolbarImages.noTrackWindow,
        },
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
              w:reload()
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

    local browser = webview.new(browserFrame, options):windowStyle(1+2+4+8)
      :allowTextEntry(true)
      :allowGestures(true)
      :closeOnEscape(true)
      :navigationCallback(function(a, w, n, e)
          if e then
              hs.luaSkinLog.ef("%s browser navigation for %s error:%s", USERDATA_TAG, a, e.localizedDescription)
              return true
          end
          if a == "didFinishNavigation" then updateToolbarIcons(w:toolbar(), w) end
      end)

    browser:toolbar(makeToolbar(browser))
    return browser
end

-- Public interface ------------------------------------------------------

--- hs.doc.hsdocs.interface([interface]) -> currentValue
--- Function
--- Get or set the network interface that the Hammerspoon documentation web server will be served on
---
--- Paramaters:
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
--- Paramters:
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

        if not module._browserWatcher and settings.get("_documentationServer.trackBrowserFrameChanges") then
            makeWatcher(module._browser)
        end
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

--- hs.doc.hsdocs.browserDarkMode([value]) -> currentValue
--- Function
--- Get or set whether or not the Hammerspoon browser renders output in Dark mode.
---
--- Paramters:
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
--- Paramters:
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
