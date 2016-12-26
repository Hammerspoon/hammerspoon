--- === hs.keycodes ===
---
--- Convert between key-strings and key-codes. Also provides funcionality for querying and changing keyboard layouts.

--- hs.keycodes.map
--- Constant
--- A mapping from string representation of a key to its keycode, and vice versa.
--- For example: keycodes[1] == "s", and keycodes["s"] == 1, and so on.
--- This is primarily used by the hs.eventtap and hs.hotkey extensions.
---
--- Valid strings are any single-character string, or any of the following strings:
---
---     f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15,
---     f16, f17, f18, f19, f20, pad, pad*, pad+, pad/, pad-, pad=,
---     pad0, pad1, pad2, pad3, pad4, pad5, pad6, pad7, pad8, pad9,
---     padclear, padenter, return, tab, space, delete, escape, help,
---     home, pageup, forwarddelete, end, pagedown, left, right, down, up

local keycodes = require "hs.keycodes.internal"
keycodes.map = keycodes._cachemap()

--- hs.keycodes.inputSourceChanged(fn)
--- Function
--- Sets the function to be called when your input source (i.e. qwerty, dvorak, colemac) changes.
---
--- Parameters:
---  * fn - A function that will be called when the input source changes. No arguments are supplied to the function.
---
--- Returns:
---  * None
---
--- Notes:
---  * This may be helpful for rebinding your hotkeys to appropriate keys in the new layout
---  * Setting this will un-set functions previously registered by this function.
function keycodes.inputSourceChanged(fn)
  if keycodes._callback then keycodes._callback:_stop() end
  keycodes._callback = keycodes._newcallback(function()
      keycodes.map = keycodes._cachemap()
      if fn then
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then hs.showError(err) end
      end
  end)
end

keycodes.inputSourceChanged()

return keycodes
