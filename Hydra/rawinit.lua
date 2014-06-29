local ok, err = pcall(function()

    -- core functions
    dofile(hydra.resourcesdir .. "/api.lua")
    dofile(hydra.resourcesdir .. "/fnutils.lua")
    dofile(hydra.resourcesdir .. "/geometry.lua")
    dofile(hydra.resourcesdir .. "/screen.lua")
    dofile(hydra.resourcesdir .. "/application.lua")
    dofile(hydra.resourcesdir .. "/window.lua")
    dofile(hydra.resourcesdir .. "/hotkey.lua")
    dofile(hydra.resourcesdir .. "/repl.lua")
    dofile(hydra.resourcesdir .. "/timer.lua")
    dofile(hydra.resourcesdir .. "/pathwatcher.lua")
    dofile(hydra.resourcesdir .. "/textgrid.lua")
    dofile(hydra.resourcesdir .. "/logger.lua")
    dofile(hydra.resourcesdir .. "/updates.lua")
    dofile(hydra.resourcesdir .. "/notify.lua")
    dofile(hydra.resourcesdir .. "/doc.lua")
    dofile(hydra.resourcesdir .. "/webview.lua")

    -- make lives of third party authors easier
    doc.ext = {__doc = "Standard high-level namespace for third-party extensions."}
    ext = {}

    package.path = hydra.userfile("?") .. ";" .. package.path

    hydra._initiate_documentation_system()

    if not hydra.check_accessibility(true) then
      notify.show("Enable accessibility first", "", "Otherwise Hydra can't do very much.", "needs_accessibility")
    end

    -- load user's config
    hydra.call(hydra.reload)

end)

if not ok then
  notify.show("Hydra apparently failed to initialize. Nothing else to do now but quit.", "", tostring(err), "")
  os.exit()
end
