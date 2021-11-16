--- === hs.dialog ===
---
--- A collection of useful dialog boxes, alerts and panels for user interaction.

--- === hs.dialog.color ===
---
--- A panel that allows users to select a color.

local USERDATA_TAG = "hs.dialog"
local module       = require("hs.libdialog")

local color = require("hs.drawing.color")

-- Private Variables & Methods -----------------------------------------

-- Public Interface ------------------------------------------------------

color.panel = module.color

--- hs.dialog.alert(x, y, callbackFn, message, [informativeText], [buttonOne], [buttonTwo], [style]) -> string
--- Function
--- Displays a simple non-blocking dialog box using `NSAlert` and a hidden `hs.webview` that's automatically destroyed when the alert is closed.
---
--- Parameters:
---  * x - A number containing the horizontal co-ordinate of the top-left point of the dialog box. Defaults to 1.
---  * y - A number containing the vertical co-ordinate of the top-left point of the dialog box. Defaults to 1.
---  * callbackFn - The callback function that's called when a button is pressed.
---  * message - The message text to display.
---  * [informativeText] - Optional informative text to display.
---  * [buttonOne] - An optional value for the first button as a string. Defaults to "OK".
---  * [buttonTwo] - An optional value for the second button as a string. If `nil` is used, no second button will be displayed.
---  * [style] - An optional style of the dialog box as a string. Defaults to "warning".
---
--- Returns:
---  * nil
---
--- Notes:
---  * The optional values must be entered in order (i.e. you can't supply `style` without also supplying `buttonOne` and `buttonTwo`).
---  * [style] can be "warning", "informational" or "critical". If something other than these string values is given, it will use "informational".
---  * Example:
---      ```testCallbackFn = function(result) print("Callback Result: " .. result) end
---      hs.dialog.alert(100, 100, testCallbackFn, "Message", "Informative Text", "Button One", "Button Two", "NSCriticalAlertStyle")
---      hs.dialog.alert(200, 200, testCallbackFn, "Message", "Informative Text", "Single Button")```
function module.alert(x, y, callback, ...)
	local rect = {
        h = 10, -- Small enough to be hidden by the alert panel
        w = 10,
        x = 1,
        y = 1,
    }
	if type(x) == "number" then rect.x = x end
	if type(y) == "number" then rect.y = y end
    local wv = hs.webview.new(rect):show()
    hs.dialog.webviewAlert(wv, function(...)
	    wv:delete()
      callback(...)
    end, ...)
end

-- Return Module Object --------------------------------------------------

return module
