local ok, err = pcall(function()

    -- core functions
    dofile(hydra.resourcesdir .. "/application.lua")
    dofile(hydra.resourcesdir .. "/doc.lua")
    dofile(hydra.resourcesdir .. "/eventtap.lua")
    dofile(hydra.resourcesdir .. "/fnutils.lua")
    dofile(hydra.resourcesdir .. "/geometry.lua")
    dofile(hydra.resourcesdir .. "/hotkey.lua")
    dofile(hydra.resourcesdir .. "/hotkey_modal.lua")
    dofile(hydra.resourcesdir .. "/http.lua")
    dofile(hydra.resourcesdir .. "/hydra.lua")
    dofile(hydra.resourcesdir .. "/hydra_ipc.lua")
    dofile(hydra.resourcesdir .. "/hydra_packages.lua")
    dofile(hydra.resourcesdir .. "/hydra_updates.lua")
    dofile(hydra.resourcesdir .. "/inspect.lua")
    dofile(hydra.resourcesdir .. "/logger.lua")
    dofile(hydra.resourcesdir .. "/notify.lua")
    dofile(hydra.resourcesdir .. "/repl.lua")
    dofile(hydra.resourcesdir .. "/screen.lua")
    dofile(hydra.resourcesdir .. "/textgrid.lua")
    dofile(hydra.resourcesdir .. "/timer.lua")
    dofile(hydra.resourcesdir .. "/window.lua")

    package.path = os.getenv("HOME") .. "/.hydra/?.lua" .. ';' .. package.path

    hydra._initiate_documentation_system()

    if not hydra.check_accessibility(true) then
      hydra.alert("Enable accessibility, so Hydra can move windows.", 7)
    end

    -- load user's config
    hydra.call(hydra.reload)

end)

if not ok then
  notify.show("Hydra apparently failed to initialize. Nothing else to do now but quit.", "", tostring(err), "")
  os.exit()
end
