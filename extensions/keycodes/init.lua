--- === hs.keycodes ===
---
--- Convert between key-strings and key-codes. Also provides functionality for querying and changing keyboard layouts.

local log = require"hs.logger".new("hs.keycodes", "warning")

-- fallback table based on ANSI-Standard US Keyboard as defined in /System/Library/Frameworks/Carbon.framework/Versions/Current/Frameworks/HIToolbox.framework/Versions/Current/Headers/Events.h as of macOS 10.12, Xcode 8.
local fallbackKeyMap = {
    ["0"]        = 0x1d,  ["1"]        = 0x12,  ["2"]        = 0x13,  ["3"]        = 0x14,
    ["4"]        = 0x15,  ["5"]        = 0x17,  ["6"]        = 0x16,  ["7"]        = 0x1a,
    ["8"]        = 0x1c,  ["9"]        = 0x19,  ["a"]        = 0x00,  ["b"]        = 0x0b,
    ["\\"]       = 0x2a,  ["c"]        = 0x08,  [","]        = 0x2b,  ["d"]        = 0x02,
    ["e"]        = 0x0e,  ["="]        = 0x18,  ["f"]        = 0x03,  ["g"]        = 0x05,
    ["`"]        = 0x32,  ["h"]        = 0x04,  ["i"]        = 0x22,  ["j"]        = 0x26,
    ["k"]        = 0x28,  ["pad0"]     = 0x52,  ["pad1"]     = 0x53,  ["pad2"]     = 0x54,
    ["pad3"]     = 0x55,  ["pad4"]     = 0x56,  ["pad5"]     = 0x57,  ["pad6"]     = 0x58,
    ["pad7"]     = 0x59,  ["pad8"]     = 0x5b,  ["pad9"]     = 0x5c,  ["padclear"] = 0x47,
    ["pad."]     = 0x41,  ["pad/"]     = 0x4b,  ["padenter"] = 0x4c,  ["pad="]     = 0x51,
    ["pad-"]     = 0x4e,  ["pad*"]     = 0x43,  ["pad+"]     = 0x45,  ["l"]        = 0x25,
    ["["]        = 0x21,  ["m"]        = 0x2e,  ["-"]        = 0x1b,  ["n"]        = 0x2d,
    ["o"]        = 0x1f,  ["p"]        = 0x23,  ["."]        = 0x2f,  ["q"]        = 0x0c,
    ["'"]        = 0x27,  ["r"]        = 0x0f,  ["]"]        = 0x1e,  ["s"]        = 0x01,
    [";"]        = 0x29,  ["/"]        = 0x2c,  ["t"]        = 0x11,  ["u"]        = 0x20,
    ["v"]        = 0x09,  ["w"]        = 0x0d,  ["x"]        = 0x07,  ["y"]        = 0x10,
    ["z"]        = 0x06,

    [0x1d] = "0",         [0x12] = "1",         [0x13] = "2",         [0x14] = "3",
    [0x15] = "4",         [0x17] = "5",         [0x16] = "6",         [0x1a] = "7",
    [0x1c] = "8",         [0x19] = "9",         [0x00] = "a",         [0x0b] = "b",
    [0x2a] = "\\",        [0x08] = "c",         [0x2b] = ",",         [0x02] = "d",
    [0x0e] = "e",         [0x18] = "=",         [0x03] = "f",         [0x05] = "g",
    [0x32] = "`",         [0x04] = "h",         [0x22] = "i",         [0x26] = "j",
    [0x28] = "k",         [0x52] = "pad0",      [0x53] = "pad1",      [0x54] = "pad2",
    [0x55] = "pad3",      [0x56] = "pad4",      [0x57] = "pad5",      [0x58] = "pad6",
    [0x59] = "pad7",      [0x5b] = "pad8",      [0x5c] = "pad9",      [0x47] = "padclear",
    [0x41] = "pad.",      [0x4b] = "pad/",      [0x4c] = "padenter",  [0x51] = "pad=",
    [0x4e] = "pad-",      [0x43] = "pad*",      [0x45] = "pad+",      [0x25] = "l",
    [0x21] = "[",         [0x2e] = "m",         [0x1b] = "-",         [0x2d] = "n",
    [0x1f] = "o",         [0x23] = "p",         [0x2f] = ".",         [0x0c] = "q",
    [0x27] = "'",         [0x0f] = "r",         [0x1e] = "]",         [0x01] = "s",
    [0x29] = ";",         [0x2c] = "/",         [0x11] = "t",         [0x20] = "u",
    [0x09] = "v",         [0x0d] = "w",         [0x07] = "x",         [0x10] = "y",
    [0x06] = "z",
}

local attachFallbackTable = function(tableMap)
    return setmetatable(tableMap, {
        __index = function(self, key)
            if type(key) == "string" then key = key:lower() end
            local newKey = rawget(self, key)
            if newKey then
                return newKey
            else
                newKey = fallbackKeyMap[key]
                if newKey then
                    log.wf("key '%s' not found in active keymap; using ANSI-standard US keyboard layout as fallback, returning '%s'", tostring(key), tostring(newKey))
                    return newKey
                else
                    log.wf("key '%s' not found in active keymap or ANSI-standard US keyboard layout", tostring(key))
                    return nil
                end
            end
        end
    })
end

--- hs.keycodes.map
--- Constant
--- A mapping from string representation of a key to its keycode, and vice versa.
--- For example: keycodes[1] == "s", and keycodes["s"] == 1, and so on.
--- This is primarily used by the hs.eventtap and hs.hotkey extensions.
---
--- Valid strings are any single-character string, or any of the following strings:
---
---     f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15,
---     f16, f17, f18, f19, f20, pad., pad*, pad+, pad/, pad-, pad=,
---     pad0, pad1, pad2, pad3, pad4, pad5, pad6, pad7, pad8, pad9,
---     padclear, padenter, return, tab, space, delete, escape, help,
---     home, pageup, forwarddelete, end, pagedown, left, right, down, up,
---     shift, rightshift, cmd, rightcmd, alt, rightalt, ctrl, rightctrl,
---     capslock, fn

local keycodes = require "hs.keycodes.internal"
keycodes.map = attachFallbackTable(keycodes._cachemap())
keycodes.log = log

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
      keycodes.map = attachFallbackTable(keycodes._cachemap())
      if fn then
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then hs.showError(err) end
      end
  end)
end

keycodes.inputSourceChanged()

return keycodes
