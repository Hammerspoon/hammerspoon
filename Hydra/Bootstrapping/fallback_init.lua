local fallbackinit = {}

function fallbackinit.open_sample_init()
  os.execute("open \"" .. hydra.resourcesdir .. "/sample_init.lua\"")
end

function fallbackinit.run()
  menu.show(function()
      return {
        {title = "Open Sample Init", fn = fallbackinit.open_sample_init},
        {title = "Reload Config", fn = hydra.reload},
        {title = "Open REPL", fn = repl.open},
        {title = "-"},
        {title = "About", fn = hydra.showabout},
        {title = "Quit Hydra", fn = os.exit},
      }
  end)

  hydra.alert("Welcome to Hydra 1.0! Click the menu icon to find a sample config :)", 10)

  hotkey.bind({"cmd", "alt", "ctrl"}, "r", repl.open)
end

return fallbackinit
