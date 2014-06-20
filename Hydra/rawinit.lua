-- core functions
dofile(api.resourcesdir .. "/api.lua")
dofile(api.resourcesdir .. "/fn.lua")
dofile(api.resourcesdir .. "/geometry.lua")
dofile(api.resourcesdir .. "/screen.lua")
dofile(api.resourcesdir .. "/app.lua")
dofile(api.resourcesdir .. "/window.lua")
dofile(api.resourcesdir .. "/hotkey.lua")

-- make lives of third party authors easier
api.ext = {}

-- load user's config
local ok, err = pcall(function()
    api.reload()
end)

-- report err in user's config
if not ok then api.alert(err, 5) end
