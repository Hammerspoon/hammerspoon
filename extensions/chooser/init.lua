--- === hs.chooser ===
---
--- Graphical, interactive tool for choosing/searching data
---
--- Notes:
---  * This module was influenced heavily by Choose, by Steven Degutis (https://github.com/sdegutis/choose)

require("hs.styledtext")
require("hs.drawing.color")
local chooser = require("hs.chooser.internal")
local window = require("hs.window")

--- hs.chooser:attachedToolbar([toolbar]) -> hs.chooser object | currentValue
--- Method
--- Get or attach/detach a toolbar to/from the chooser.
---
--- Parameters:
---  * `toolbar` - An `hs.webview.toolbar` object to be attached to the chooser. If `nil` is supplied, the current toolbar will be removed
---
--- Returns:
---  * if a toolbarObject or explicit nil is specified, returns the hs.chooser object; otherwise returns the current toolbarObject or nil, if no toolbar is attached to the chooser.
---
--- Notes:
---  * this method is a convenience wrapper for the `hs.webview.toolbar.attachToolbar` function.
---
---  * If the toolbarObject is currently attached to another window when this method is called, it will be detached from the original window and attached to the chooser.  If you wish to attach the same toolbar to multiple chooser objects, see `hs.webview.toolbar:copy`.
hs.getObjectMetatable("hs.chooser").attachedToolbar = require"hs.webview.toolbar".attachToolbar

--- hs.chooser.globalCallback
--- Variable
--- A global callback function used for various hs.chooser events
---
--- Notes:
---  * This callback should accept two parameters:
---   * An `hs.chooser` object
---   * A string containing the name of the event to handle. Possible values are:
---    * `willOpen` - An hs.chooser is about to be shown on screen
---    * `didClose` - An hs.chooser has just been removed from the screen
---  * There is a default global callback that uses the `willOpen` event to remember which window has focus, and the `didClose` event to restore focus back to the original window. If you want to use this in addition to your own callback, you can call it as `hs.chooser._defaultGlobalCallback(event)`

-- create focus store if it doesn't already exist
if not chooser._lastFocused then
  chooser._lastFocused = {}
end

chooser._defaultGlobalCallback = function(whichChooser, state)
  if state == "willOpen" then
    chooser._lastFocused[whichChooser] = window.frontmostWindow()
  elseif state == "didClose" then
    local initialChooserUserdata = nil
    for k,_ in pairs(chooser._lastFocused) do
      if k == whichChooser then -- assumes userdata implements __eq method
        initialChooserUserdata = k
        break
      end
    end
    -- might not be found if no window was focused before the chooser was opened, so check
    if initialChooserUserdata and chooser._lastFocused[initialChooserUserdata] then
      chooser._lastFocused[initialChooserUserdata]:focus()
      chooser._lastFocused[initialChooserUserdata] = nil
    end
  else
    hs.printf("** unrecognized state for chooser: %s", state)
  end
end
chooser.globalCallback = chooser._defaultGlobalCallback

return chooser
