local mod = {}

-------------------------------------------------------------------------------
-- CONSTANTS:
-------------------------------------------------------------------------------

mod.extensionsPath		= hs.processInfo["resourcePath"] .. "/extensions/"
mod.scriptVersion       = "0.79"
mod.bugReportEmail      = "chris@latenitefilms.com"
mod.developerURL        = "https://latenitefilms.com/blog/final-cut-pro-hacks/"
mod.updateURL           = "https://latenitefilms.com/blog/final-cut-pro-hacks/#download"
mod.checkUpdateURL      = "https://latenitefilms.com/downloads/fcpx-hammerspoon-version.html"
mod.assetsPath			= mod.extensionsPath .. "hs/fcpxhacks/assets/"
mod.iconPath            = mod.assetsPath .. "fcpxhacks.icns"

return mod