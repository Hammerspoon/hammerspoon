--- === hs.uielement ===
--- A generalized framework for working with OSX UI elements.

local uielement = require "hs.uielement.internal"

--- hs.uielement.watcher
--- Defines events that can be watched using hs.uielement.watcher.
---
--- You can watch the following events:
--- ### Application-level events
--- See hs.application.watcher for more events you can watch.
--- * hs.uielement.watcher.applicationActivated: The current application switched to this one.
--- * hs.uielement.watcher.applicationDeactivated: The current application is no longer this one.
--- * hs.uielement.watcher.applicationHidden: The application was hidden.
--- * hs.uielement.watcher.applicationShown: The application was shown.
--- #### Focus change events
--- These events are watched on the application level, but send the relevant child element to the handler.
--- * hs.uielement.watcher.mainWindowChanged: The main window of the application was changed.
--- * hs.uielement.watcher.focusedWindowChanged: The focused window of the application was changed. Note that the application may not be activated itself.
--- * hs.uielement.watcher.AXFocusedUIElementChanged: The focused UI element of the application was changed.
---
--- ### Window-level events
--- * hs.uielement.watcher.windowCreated: A window was created. You should watch for this event on the application, or the parent window.
--- * hs.uielement.watcher.windowMoved: The window was moved.
--- * hs.uielement.watcher.windowResized: The window was resized.
--- * hs.uielement.watcher.windowMinimized: The window was minimized.
--- * hs.uielement.watcher.windowUnminimized: The window was unminimized.
---
--- ### Element-level events
--- These work on all UI elements, including windows.
--- * hs.uielement.watcher.elementDestroyed: The element was destroyed. Call watcher:stop() when this happens.
--- * hs.uielement.watcher.titleChanged: The element's title was changed.
uielement.watcher = {
    applicationActivated   = "AXApplicationActivated",
    applicationDeactivated = "AXApplicationDeactivated",
    applicationHidden      = "AXApplicationHidden",
    applicationShown       = "AXApplicationShown",

    mainWindowChanged     = "AXMainWindowChanged",
    focusedWindowChanged  = "AXFocusedWindowChanged",
    focusedElementChanged = "AXFocusedUIElementChanged",

    windowCreated     = "AXWindowCreated",
    windowMoved       = "AXWindowMoved",
    windowResized     = "AXWindowResized",
    windowMinimized   = "AXWindowMiniaturized",
    windowUnminimized = "AXWindowDeminiaturized",

    elementDestroyed = "AXUIElementDestroyed",
    titleChanged     = "AXTitleChanged"
}

return uielement
