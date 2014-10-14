-- `package` is the require-path.
--
--    Note: this must match the filename also.
package = "hs.notification"

-- `version` has two parts, your module's version (0.1) and the
--    rockspec's version (1) in case you change metadata without
--    changing the module's source code.
--
--    Note: the version must match the version in the filename.
version = "0.1-1"

-- General metadata:

local url = "github.com/asmagill/mjolnir_asm.ui"
local desc = "A more powerful use of Apple's built-in notifications system for Hammerspoon."

source = {url = "git://" .. url, dir = "mjolnir_asm.ui/notification"}
description = {
  summary = desc,
  detailed = desc,
  homepage = "https://" .. url,
  license = "MIT",
}

-- Dependencies:

supported_platforms = {"macosx"}
dependencies = {
  "lua >= 5.2",
}

-- Build rules:

build = {
  type = "builtin",
  modules = {
    ["hs.notification"] = "init.lua",
    ["hs.notification.internal"] = "internal.m",
  },
}
