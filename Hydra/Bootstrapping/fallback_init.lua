local fallbackinit = {}

function fallbackinit.open_sample_init()
  os.execute("open \"" .. hydra.resourcesdir .. "/sample_init.lua\"")
end

function fallbackinit.run()
  hydra.menu.show(function()
      local t = {
        {title = "Open Sample Initfile", fn = fallbackinit.open_sample_init},
        {title = "Reload Config", fn = hydra.reload},
        {title = "Open REPL", fn = repl.open},
        {title = "-"},
        {title = "About", fn = hydra.showabout},
        {title = "Quit Hydra", fn = os.exit},
      }

      if not hydra.license.haslicense() then
        table.insert(t, 1, {title = "Buy or Enter License...", fn = hydra.license.enter})
        table.insert(t, 2, {title = "-"})
      end

      return t
  end)

  hydra.alert("Welcome to Hydra 1.0! Click the menu icon to find a sample config :)", 10)

  hotkey.bind({"cmd", "alt", "ctrl"}, "r", hydra.reload)
end

return fallbackinit
