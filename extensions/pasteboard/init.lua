--- === hs.pasteboard ===
---
--- Inspect/manipulate pasteboards (more commonly called clipboards). Both the system default pasteboard and custom named pasteboards can be interacted with.
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.pasteboard.internal")
module.watcher = require("hs.pasteboard.watcher")

local timer = require("hs.timer")

-- make sure the convertors for types we can recognize are loaded
require("hs.image")
require("hs.sound")
require("hs.styledtext")
require("hs.drawing.color")
require("hs.sharing")

-- Public interface ------------------------------------------------------

--- hs.pasteboard.readAllData([name]) -> table
--- Function
--- Returns all values in the first item on the pasteboard in a table that maps a UTI value to the raw data of the item
---
--- Parameters:
---  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
---
--- Returns:
---   a mapping from a UTI value to the raw data
module.readAllData = function (name)
  local contents = {}
  for _, uti in ipairs(module.contentTypes(name)) do
    contents[uti] = module.readDataForUTI(name, uti)
  end
  return contents
end

--- hs.pasteboard.writeAllData([name], table) -> boolean
--- Function
--- Stores in the pasteboard a given table of UTI to data mapping all at once
---
--- Parameters:
---  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
---  * a mapping from a UTI value to the raw data
---
--- Returns:
---   * True if the operation succeeded, otherwise false (which most likely means ownership of the pasteboard has changed)
module.writeAllData = function (...)
  local name, contents
  if #{...} == 1 then
    contents = ...
  else
    name, contents = ...
  end

  local ok = true
  module.clearContents(name)
  for uti, data in pairs(contents) do
    ok = ok and module.writeDataForUTI(name, uti, data, true)
  end
  return ok
end

--- hs.pasteboard.callbackWhenChanged([name], [timeout], callback) -> None
--- Function
--- Invokes callback when the specified pasteoard has changed or the timeout is reached.
---
--- Parameters:
---  * `name`     - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
---  * `timeout`  - an optional number, default 2.0, specifying the time in seconds that this function should wait for a change to the specified pasteboard before timing out.
---  * `callback` - a required callback function that will be invoked when either the specified pasteboard contents have changed or the timeout has been reached. The function should expect one boolean argument, true if the pasteboard contents have changed or false if timeout has been reached.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function can be used to capture the results of a copy operation issued programatically with `hs.application:selectMenuItem` or `hs.eventtap.keyStroke` without resorting to creating your own timers:
---
---  ~~~
---      hs.eventtap.keyStroke({"cmd"}, "c", 0) -- or whatever method you want to trigger the copy
---      hs.pasteboard.callbackWhenChanged(5, function(state)
---          if state then
---              local contents = hs.pasteboard.getContents()
---              -- do what you want with contents
---          else
---              error("copy timeout") -- or whatever fallback you want when it timesout
---          end
---      end)
--- ~~~
module.callbackWhenChanged = function(...)
    local name, timeout, callback = nil, 2.0, nil
    for _, v in ipairs({...}) do
        if type(v) == "number" then
            timeout = v
        elseif type(v) == "nil" or type(v) == "string" then
            name = v
        elseif type(v) == "function" or (getmetatable(v) or {}).__call then
            callback = v
        end
    end
    assert(type(name) == "nil" or type(name) == "string", "pasteboard must be a string or nil")
    assert(type(timeout) == "number", "timeout must be a number")
    assert(
        type(callback) == "function" or (getmetatable(callback) or {}).__call,
        "callback must be a function"
    )

    local longTask
    longTask = coroutine.wrap(function(start, count)
        while (timer.secondsSinceEpoch() - start < timeout) and (module.changeCount(name) == count) do
              coroutine.applicationYield() -- luacheck: ignore
        end
        callback(module.changeCount(name) ~= count)
        longTask = nil -- referncing here makes it an upvalue, so it won't be collected
    end)
    longTask(timer.secondsSinceEpoch(), module.changeCount(name))
end

return module
