
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

local module = {}
local settings = require"hs.settings"

local documentRoot = package.searchpath("hs.doc.hsdocs", package.path):match("^(/.*/).*%.lua$")

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
---  * This value is stored in the Hammerspoon application defaults with the label "_documentationServer.serverPort".
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
---  * This function is automatically called, if necessary, when `hs.doc.hsdocs.help` is invoked.
---  * The documentation web server can be viewed from a web browser by visiting "http://localhost:port" where `port` is the port the server is running on, 12345 by default -- see `hs.doc.hsdocs.port`.
module.start = function()
    if module._server then
        error("documentation server already running")
    else
        module._server = require"hs.httpserver.hsminweb".new(documentRoot)
        module._server:port(module.port())
                     :name("Hammerspoon Documentation")
                     :bonjour(true)
                     :luaTemplateExtension("lp")
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

    local webview  = require"hs.webview"
    if webview and not settings.get("_documentationServer.forceExternalBrowser") then
        if not module._browser then
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

            module._browser = webview.new(browserFrame, {
                developerExtrasEnabled=true,
                privateBrowsing=true,
            }):windowStyle(1+2+4+8)
              :allowTextEntry(true)
              :allowGestures(true)
              :closeOnEscape(true)
        end

        module._browser:url(targetURL):show()

        if not module._browserWatcher and settings.get("_documentationServer.trackBrowserFrameChanges") then
            require"hs.timer".waitUntil(
                function() return module._browser:asHSWindow() ~= nil end,
                function(...)
                    module._browserWatcher = module._browser:asHSWindow()
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
    else
        os.execute("/usr/bin/open " .. targetURL)
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
---  * If `hs.doc.hsdocs.trackBrowserFrame` is false or nil (the default), then you can use this function to specify the initial position of the documentation browser.
---  * If `hs.doc.hsdocs.trackBrowserFrame` is true, then this any value set with this function will be overwritten whenever the browser window is moved or resized.
---
---  * This value is stored in the Hammerspoon application defaults with the label "_documentationServer.browserFrame".
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
---  * This value is stored in the Hammerspoon application defaults with the label "_documentationServer.trackBrowserFrameChanges".
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
---  * This value is stored in the Hammerspoon application defaults with the label "_documentationServer.invertDocs".
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
---  * value - an optional boolean, default false, specifying whether or not documentation requests will be displayed in an external browser or the internal one handled by `hs.webview`.
---
--- Returns:
---  * the current, possibly new, value
---
--- Notes:
---  * If this value is set to true, help requests invoked by [hs.doc.hsdocs.help](#help) will be invoked by `os.execute("open *targetURL*"), rendering the documentation in your default browser.
---  * This behavior is triggered automatically, regardless of this setting, if you are running with a version of OS X prior to 10.10, since `hs.webview` requires OS X 10.10 or later.
---
---  * This value is stored in the Hammerspoon application defaults with the label "_documentationServer.forceExternalBrowser".
module.forceExternalBrowser = function(...)
    local args = table.pack(...)
    if args.n == 1 and (type(args[1]) == "boolean" or type(args[1]) == "nil") then
        settings.set("_documentationServer.forceExternalBrowser", args[1])
    end
    return settings.get("_documentationServer.forceExternalBrowser")
end

return module