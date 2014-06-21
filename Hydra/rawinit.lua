-- core functions
dofile(api.resourcesdir .. "/api.lua")
dofile(api.resourcesdir .. "/fn.lua")
dofile(api.resourcesdir .. "/geometry.lua")
dofile(api.resourcesdir .. "/screen.lua")
dofile(api.resourcesdir .. "/app.lua")
dofile(api.resourcesdir .. "/window.lua")
dofile(api.resourcesdir .. "/hotkey.lua")
dofile(api.resourcesdir .. "/repl.lua")
dofile(api.resourcesdir .. "/timer.lua")

-- make lives of third party authors easier
api.ext = {}

-- load user's config
api.call(api.reload)
