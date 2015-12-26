--- === hs.chooser ===
---
--- Graphical, interactive tool for choosing/searching data
---
--- Notes:
---  * This module is only available on OS X >= 10.9
---  * This module was influenced heavily by Choose, by Steven Degutis (https://github.com/sdegutis/choose)

host = require("hs.host")
osVersion = host.operatingSystemVersion()

if (osVersion["major"] == 10 and osVersion["minor"] < 9) then
  print("ERROR: hs.chooser is only available on OS X 10.9 or later")
  return nil
end

local chooser = require "hs.chooser.internal"
return chooser
