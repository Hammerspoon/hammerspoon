-- keep this stuff
dofile(hydra.resourcesdir .. "/hydra.lua")
dofile(hydra.resourcesdir .. "/fn.lua")
dofile(hydra.resourcesdir .. "/geometry.lua")
dofile(hydra.resourcesdir .. "/screen.lua")
dofile(hydra.resourcesdir .. "/app.lua")
dofile(hydra.resourcesdir .. "/window.lua")

-- load user's config
local ok, err = pcall(function()
    hydra.reload()
end)

-- report err in user's config
if not ok then hydra.alert(err, 5) end
