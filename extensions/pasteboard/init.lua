--- === hs.pasteboard ===
---
--- Inspect/manipulate pasteboards (more commonly called clipboards). Both the system default pasteboard and custom named pasteboards can be interacted with.
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.pasteboard.internal")
module.watcher = require("hs.pasteboard.watcher")

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

return module
