-- core functions
dofile(api.resourcesdir .. "/api.lua")
dofile(api.resourcesdir .. "/fnutils.lua")
dofile(api.resourcesdir .. "/geometry.lua")
dofile(api.resourcesdir .. "/screen.lua")
dofile(api.resourcesdir .. "/application.lua")
dofile(api.resourcesdir .. "/window.lua")
dofile(api.resourcesdir .. "/hotkey.lua")
dofile(api.resourcesdir .. "/repl.lua")
dofile(api.resourcesdir .. "/timer.lua")
dofile(api.resourcesdir .. "/pathwatcher.lua")
dofile(api.resourcesdir .. "/textgrid.lua")
dofile(api.resourcesdir .. "/logger.lua")
dofile(api.resourcesdir .. "/updates.lua")
dofile(api.resourcesdir .. "/notify.lua")
dofile(api.resourcesdir .. "/doc.lua")
dofile(api.resourcesdir .. "/webview.lua")

-- make lives of third party authors easier
doc.api.ext = {__doc = "Standard high-level namespace for third-party extensions."}
api.ext = {}

package.path = api.userfile("?") .. ";" .. package.path

api._initiate_documentation_system()

if not api.check_accessibility(true) then
  api.notify.show("Enable accessibility first", "", "Otherwise Hydra can't do very much.", "needs_accessibility")
end

-- load user's config
api.call(api.reload)
